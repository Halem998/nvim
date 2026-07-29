# Implementation Plan: Task #945

- **Task**: 945 - Converge conflict detection onto one bounded predicate over locks, registry, and state
- **Status**: [IMPLEMENTING]
- **Effort**: 11.5 hours
- **Dependencies**: 944 (session registry — landed)
- **Research Inputs**: specs/945_converge_conflict_detection_predicate/reports/01_converge-conflict-predicate.md
- **Artifacts**: plans/01_converge-conflict-predicate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Collapse the two independent transcriptions of the directory-prefix overlap predicate into one
physical implementation in `scripts/lib/file-scope-overlap.sh`, then extend that single
implementation with a third bounded contention input — the session registry — consumed by both
`task-lock.sh acquire` and `orchestrate-batch-admit.sh`. The verdict schema bumps to
`orchestrate-batch-admit-v4` for the new defer flavor. The two downstream report composers
inherit the converged predicate through their existing subprocess relationship and are verified,
not rewritten. Finally, batch admission is wired into the three plain multi-task command paths
that today have only per-task locking.

### Research Integration

The research report corrects the task description's framing in five load-bearing ways, all of
which this plan encodes rather than rediscovers:

1. **Gap B has not drifted.** `scopes_overlap()` (bash-wrapped `jq -n`) and
   `scopes_overlap_first()` (a jq `def` inside one `jq -n --slurpfile` program) are semantically
   identical today. This is preventive convergence, not a bug fix — so the correctness bar for
   Phase 1 is *byte-for-byte behavioral identity*, not "fix the discrepancy."
2. **Only two of the four named consumers implement the algorithm.**
   `orchestrate-predispatch-review.sh` and `orchestrate-dry-run-report.sh` subprocess-call
   `orchestrate-batch-admit.sh` and consume its NDJSON. No conversion work is planned for them;
   Phase 6 verifies the inheritance instead.
3. **Held locks are not an independent scope source.** `holder.json` carries no `file_scope`; the
   other side's scope is always re-fetched from `specs/state.json` via `get_file_scope`. Input 1
   is a liveness/confidence signal layered on input 3. Only input 2 (the session registry) carries
   its own precomputed, unioned `file_scope`.
4. **The session registry has zero readers by design.** `task-lock.md`'s "Non-Goal: No Reader"
   section must be *replaced by* the reader's contract, not left standing and contradicted.
5. **A third contention input forces a version bump**, per `batch-admit-schema.md`'s own
   v1→v2→v3 precedent of version-bumping (never additive) on any defer-shape or defer-semantics
   change.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied and no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- One physical location for the directory-prefix overlap match rule, consumed by both scripts
  that implement it.
- One documented predicate answering "is this candidate's `file_scope` contended, and by what",
  with each of the three inputs' semantics stated explicitly and asymmetrically (they are not
  three of a kind).
- Batch admission extended to plain multi-task `/research`, `/plan`, `/implement`.
- Documentation set (`file-footprint-overlap.md`, `task-lock.md`, `batch-admit-schema.md`,
  `batch-orchestration-guardrails.md`) converged onto the single implementation.

**Non-Goals**:
- Any change to what happens *on* a detected conflict (abort/skip/wait/re-sequence). DETECTION
  only — the response belongs to the next task in this topic.
- Any relaxation of the existing `file_scope` collision or self-modification checks from blocking
  to advisory.
- Any change to the `in_batch` / `cross_batch` deferral-direction rule or the dependency-edge
  exclusion in the existing state.json comparison branch.
- Adding a held-lock filesystem scan to `orchestrate-batch-admit.sh` (see Decision D5 — rejected
  with reason).
- Any unbounded scan of every task directory.

## Resolved Design Decisions

The research report left five open design questions. All five are resolved here. Each carries the
rejected alternative and the deciding factor, so a later reader does not re-litigate them.

### D1 — Shared library shape: a `.sh` lib, not a `.jq` lib

**Decision**: `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`, a bash-sourceable
library exporting BOTH (a) a callable bash function `scopes_overlap()` with today's exact
signature and return convention, and (b) a variable `FILE_SCOPE_OVERLAP_JQ_DEFS` holding the jq
`def` text for splicing into a larger `jq -n` program.

**Rejected**: the research report's recommended option (a), a `.jq`-only lib text-spliced by both
callers.

**Deciding factor**: a `.jq` file is a new file type in a deploy path whose copy behavior is a
*documented, unresolved gap* in this repository — `rules/source-store-deploy-boundary.md`'s
companion note in `.claude/CLAUDE.md` records that the headless "Load Core" sync does not re-run
`copy_scripts` for already-loaded extensions, and specifically names `scripts/lib/*.sh` as having
silently failed to reach `.claude/scripts/lib/` once already. Introducing a *second* uncertainty
(does the copy glob even match `*.jq`?) on top of a known-flaky copy path, for orchestrator-critical
machinery whose failure mode is a broken `task-lock.sh`, is not a trade worth making. The `.sh`
form matches the cited precedent `scripts/lib/task-reference-patterns.sh` exactly — same
directory, same extension, same sourcing mechanism, and that file is confirmed present in the
deployed tree.

**The rejected option's only cost is neutralized**: research flagged option (b)'s readability
penalty as "encoding jq source as a bash string literal (escaping cost, since the jq body contains
`"`/`+`/`|`)". Assigning via a *quoted* heredoc (`read -r -d '' FILE_SCOPE_OVERLAP_JQ_DEFS <<'JQDEFS'`)
performs no expansion at all, so the jq body is stored verbatim with zero escaping. The stated
cost does not materialize.

### D2 — Schema version: `orchestrate-batch-admit-v4`

**Decision**: bump the `$schema` literal to `"orchestrate-batch-admit-v4"` and write a "v3 to v4"
Version History entry mirroring the two existing entries, including the same "every in-repo
consumer's status as of v4" table the v3 entry carries.

**Rejected**: folding the new input into the existing `file_scope_collision` shape as optional
evidence fields only, leaving `$schema` at v3.

**Deciding factor**: the new input can produce a defer that no existing `defer_reason` branch
describes (D3 below), which is exactly the v1→v2 change shape the schema doc's own Version History
names as its reason for version-bumping rather than adding fields.

### D3 — New `defer_reason: "session_active"`, plus `corroborated_by` on existing collisions

**Decision**: two changes to the verdict shape, in this precedence order:

1. `defer_reason: "self_modifying"` — unchanged, still runs first and still short-circuits.
2. `defer_reason: "file_scope_collision"` — unchanged in every existing field, plus a new
   `corroborated_by` array naming which inputs agreed (`"non_terminal_status"`, and
   `"session_registry"` when a live session also covers the colliding task number).
3. `defer_reason: "session_active"` — NEW, reached only when the state.json collision scan found
   no hit. Fires when a live registered session's own unioned `file_scope` overlaps the
   candidate's and that session is not excluded (D4).

**The load-bearing invariant this ordering buys**: *every input that produces a `defer` verdict
today produces the identical defer verdict after this change*, modulo the `$schema` string and the
added `corroborated_by` field. The new flavor fires strictly where today's predicate emits
`admit`. This makes the change provably non-regressive on the existing branch and is the property
Phase 8's regression cases assert.

**Rejected**: running the session pass first, or merging both into one verdict with combined
evidence and no new `defer_reason`. Rejected because either would change the verdict emitted for
inputs that already defer today, forfeiting the invariant above.

### D4 — Session exclusion rules

Three exclusions, in this order:

1. **Self-exclusion by session id** (mirrors `cmd_acquire`'s existing same-session bypass: "a
   session's own concurrent work never blocks itself"). A session entry whose `session_id` equals
   the caller's own is never contending.
2. **Liveness exclusion**: a session confirmed `dead-pid` or `stale-heartbeat` does NOT contend.
   `live == true`, `corrupt`, and undeterminable-liveness entries DO contend. This mirrors the
   lock layer's existing "stale acts like it is not there" philosophy rather than inventing a new
   one, and follows the recorded precision position (a false positive costs a deferred task, not
   silent data loss).
3. **Dependency-edge exclusion, evaluated per covered task number**: a session entry is excluded
   iff EVERY task number in its `task_numbers` array is either the candidate itself or connected
   to the candidate by a `dependencies[]` edge in either direction. If the session covers even one
   task number that is neither, the session contends.

   **Rationale for the "even one" direction** (research's open question 4): the exclusion's
   justification is "an explicit edge already serializes that pair" — which covers only the
   edge-connected numbers. A session covering `{edge-connected task, unrelated task}` is doing
   work on the unrelated task that nothing serializes, and its `file_scope` is a precomputed
   *union* that cannot be attributed back to individual task numbers. The conservative direction
   is to contend. The reported colliding task number is the lowest covered task number that is
   not itself excluded.

### D5 — `orchestrate-batch-admit.sh` does NOT gain a held-lock scan

**Decision**: input 1 (held locks) is consumed only by `task-lock.sh acquire`, which already
consumes it. `orchestrate-batch-admit.sh` consumes inputs 2 and 3 only.

**Deciding factor**: input 1 supplies no scope data of its own (research finding: `holder.json`
carries no `file_scope`), so it can produce no detection that input 3 does not already produce —
it only raises confidence in an already-found hit. Adding it would require a repo-wide filesystem
walk of every `.lock/` directory, directly contradicting the invariant stated in
`orchestrate-batch-admit.sh`'s own header ("no repo-wide filesystem walk of any kind"), for zero
new detections. The convergence for input 1 is therefore *definitional* — the unified predicate
document names all three inputs and their asymmetric semantics — not a new scan.

### D6 — `--session-id` is required for the session input; omitting it degrades visibly

**Decision**: `orchestrate-batch-admit.sh` gains an optional `--session-id <id>` flag. When
supplied, the session-registry input is active with self-exclusion. When omitted, the session
input is SKIPPED entirely and one loud line goes to stderr naming the skip and its consequence —
following the script's existing D5 degradation precedent ("degrade visibly, never silently").

**Deciding factor — this prevents a fatal self-block.** Gap C wires the batch-admission call
immediately AFTER `session-register`, so by the time the script runs, a session covering the
entire candidate set with their unioned `file_scope` is already on disk. Without knowing its own
session id, the script would see that session as foreign and defer every candidate in the batch
against itself. Skipping the input when identity is unknown is the only correct default; treating
one's own session as foreign is a guaranteed deadlock, and silently including it is worse than
visibly skipping it. Every call site this plan wires passes `--session-id`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new `scripts/lib/file-scope-overlap.sh` never reaches the deployed `.claude/scripts/lib/`, per the documented loader gap for new files under already-loaded extensions | H | M | Phase 1 verification explicitly confirms the deployed copy exists before the phase closes, using the same one-off loader copy-primitive invocation recorded for the prior `scripts/lib/` file. Both consumers fail CLOSED (exit 2, loud message naming the gap and remedy) if the lib is unsourceable — never a silently degraded overlap check |
| Refactoring `cmd_session_reap` to share `session_liveness()` silently changes reap behavior | H | M | `test-task-lock-reap.sh` and `test-session-registry.sh` must pass UNCHANGED after Phase 2; they are the gate, not an afterthought |
| Batch-admit self-blocks against its own just-registered session | H | M | D6: session input inert without `--session-id`; Phase 8 asserts a self-exclusion case explicitly |
| A v4 defer_reason a downstream composer does not branch on is silently dropped from a report | M | M | Phase 6 re-verifies both composers empirically against a live `session_active` verdict rather than inheriting the v2→v3 "survived unedited" precedent as an assumption |
| Gap C wiring moves a deferred task to the wrong bucket — `plan.md` names both `skipped_tasks` and `invalid_tasks` where `research.md`/`implement.md` name only `skipped_tasks` | M | M | Phase 7 follows each file's OWN existing bucket-naming convention verbatim; uniformity across the three is not assumed |
| Convergence introduces a behavioral change to an existing defer path | H | L | D3's non-regression invariant; Phase 8 asserts the in_batch/cross_batch direction rule and dependency exclusion bit-for-bit |
| Session-contention rule gets transcribed twice (once in bash for acquire, once in jq for batch-admit) — gap B recreated one layer down | M | M | The rule lives once, as a jq `def` in the shared lib, spliced by both callers (Phase 3) |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4, 5 | 3 |
| 5 | 6, 7 | 4 |
| 6 | 8 | 4, 5, 6, 7 |
| 7 | 9 | 8 |

Phases within the same wave can execute in parallel. Phases 2 and 5 both edit `task-lock.sh` and
are deliberately serialized behind Phase 1 rather than parallelized, to keep one owner per file
per wave.

**Binding constraints applying to EVERY phase below** (restated once, not repeated per phase):

- **SOURCE-STORE RULE**: every edit targets `agent-system/extensions/core/**`. Never `.claude/**`.
- **BOUNDED SCAN ONLY**: no unbounded scan of every task directory. The session input's scan is
  the dedicated `specs/.sessions/` directory glob; the state input's scan is one `state.json` read.
- **EXCLUDE, NEVER AUTO-EXPAND THE BATCH.**
- **BLOCKING STAYS BLOCKING**: the existing `file_scope` collision and self-modification checks
  are not relaxed to advisory. The blocking criterion is a conjunction (computable from on-disk
  state alone AND the harm of skipping is silent and hard to detect).
- **PRESERVE BIT-FOR-BIT**: `in_batch` defers only against a LOWER `project_number`; `cross_batch`
  defers unconditionally; dependency-connected pairs (edges in either direction) are excluded from
  comparison entirely.
- **DETECTION ONLY**: no change to what happens on a detected conflict.
- **PRECISION**: the predicate is directory-prefix based and coarse. A false positive costs a
  deferred task, not silent data loss. Never trade precision for correctness.
- **Anchor on symbol names and quoted strings, never on line numbers.**
- Any `specs/state.json` write routes through `scripts/state-write.sh`. (No phase here should
  need one — this is a read-only predicate.)
- Deliverables outside `specs/**` must not cite task numbers; use durable anchors.

---

### Phase 1: Extract the overlap predicate into one shared library [COMPLETED]

**Goal**: One physical location for the directory-prefix match rule, with both existing consumers
rewired to it and provably identical behavior.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` with a header
      comment naming `context/patterns/file-footprint-overlap.md` as the prose definition this
      file transcribes exactly once. *(completed)*
- [x] Define `FILE_SCOPE_OVERLAP_JQ_DEFS` via a quoted heredoc (`<<'JQDEFS'`, no expansion),
      containing verbatim: `def norm`, `def scopes_overlap_first(own_scope; other_scope)`, and
      `def self_mod_match($cscope; $crit)` — including `self_mod_match`'s existing NOTE comment
      explaining why it uses `first` and never `first // empty`. *(completed)*
- [x] Define the bash function `scopes_overlap()` in the lib with today's exact signature
      (`scopes_overlap "$scope_a" "$scope_b"`), return convention (first overlapping path from the
      foreign side, empty on no match), and `2>/dev/null` suppression, implemented by splicing
      `$FILE_SCOPE_OVERLAP_JQ_DEFS` into its `jq -n` program. *(completed; verified byte-identical
      against the six original scopes_overlap() test cases: exact match, either-side prefix,
      trailing-slash normalization, no-overlap, empty scope, null scope)*
- [x] In `task-lock.sh`: delete the local `scopes_overlap()` definition and source the lib.
      Sourcing failure exits 2 with a loud message naming the source-store path, the deployed
      path, and the loader-copy remedy. Fail CLOSED — never fall back to an inline copy or to
      skipping the check. *(completed: deviation from the literal task text — the sourcing is
      LAZY, via a new `ensure_file_scope_overlap_lib()` helper called only inside `cmd_acquire`
      immediately before the overlap-check loop, not unconditionally at file-top. An
      unconditional top-of-file source broke `test-task-lock-reap.sh` and
      `test-session-registry.sh` — both fixtures copy only `task-lock.sh` +
      `deploy-root-guard.sh` into their isolated `$TMPROOT`, and neither `reap` nor any
      `session-*` subcommand ever called `scopes_overlap()`, so failing the entire CLI on a
      missing lib was a strictly larger blast radius than the original code had. The fail-closed
      guarantee (exit 2, loud message, never a silent skip) is preserved exactly for the one
      caller — `cmd_acquire` — that actually needs the predicate. See Verification below.)*
- [x] In `orchestrate-batch-admit.sh`: delete the inline `scopes_overlap_first` and
      `self_mod_match` defs and splice `$FILE_SCOPE_OVERLAP_JQ_DEFS` into the `jq -n --slurpfile`
      program string. Same fail-closed sourcing behavior. *(completed; this script IS
      unconditionally single-purpose about the predicate, so top-of-file sourcing is correct
      here and unchanged from the task text)*
- [x] Update `orchestrate-batch-admit.sh`'s header comment where it says the script "transcribes"
      the algorithm and "mirrors task-lock.sh scopes_overlap() exactly" — after this phase it
      SPLICES the one shared definition and mirrors nothing. *(completed)*

**Discovery (Scope Hypothesis confirmation)**: `grep -rn 'rtrimstr("/")' agent-system/extensions/core/`
found FOUR hits, not two: (1) `lib/file-scope-overlap.sh` (the new canonical lib, expected), (2)
`orchestrate-batch-admit.sh` line 30 (a prose comment only, post-splice — no code), (3)
`events-query.sh` line 125 (`rtrimstr` used to normalize a `cwd` path for a `repo` field — a
wholly unrelated domain, not a file_scope overlap transcription), and (4)
`orchestrate-predispatch-review.sh` line 312, `def norm: rtrimstr("/");` — investigated and
confirmed NOT a transcription of the full predicate: it defines only the bare normalization
helper, reused locally for that script's own Class C (self-modification declaration-coarseness)
diagnostic, which matches a scope entry against a `critical_path` string directly rather than
calling `scopes_overlap_first`/`self_mod_match`. It never re-derives the overlap RULE itself. Per
research finding #2, `orchestrate-predispatch-review.sh` is a pure NDJSON consumer of
`orchestrate-batch-admit.sh`'s verdicts (re-verified in Phase 6), not a fifth implementer of the
predicate. The Scope Hypothesis's "exactly two files transcribe the predicate" therefore holds;
no third site required convergence in this phase.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts exactly two files currently transcribe the predicate
(`task-lock.sh`, `orchestrate-batch-admit.sh`). Confirm at implementation time with
`grep -rn "rtrimstr(\"/\")" agent-system/extensions/core/` — if a third site exists, converge it
here rather than deferring it, and record the discovery in the phase notes.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - NEW, the single definition
- `agent-system/extensions/core/scripts/task-lock.sh` - source lib, delete local `scopes_overlap()`
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - splice defs, delete inline copies

**Verification**:
- `bash scripts/test-task-lock-reap.sh` and `bash scripts/test-session-registry.sh` pass unchanged.
- Behavioral identity spot-check: run `orchestrate-batch-admit.sh` over the current live candidate
  set before and after the change and diff the NDJSON — must be byte-identical.
- Confirm `.claude/scripts/lib/file-scope-overlap.sh` exists in the deployed tree after the
  loader-copy step; if it does not, the phase is not complete.
- `grep -c "rtrimstr" agent-system/extensions/core/scripts/` returns hits only from the lib.

---

### Phase 2: Factor `session_liveness()` out of reap and add `session-list` [COMPLETED]

**Goal**: The session registry gets its first read surface, with the two-signal liveness rule
computed in exactly one place.

**Tasks**:
- [x] Extract the two-signal dead-pid / stale-heartbeat computation currently embedded inside
      `cmd_session_reap` into a shared bash function `session_liveness()` that, given an entry
      file path, yields the computed age plus one of `pid-alive` | `dead-pid` |
      `stale-heartbeat` | `corrupt` | `undeterminable`. Preserve the existing evaluation ORDER
      (dead-pid tested first, stale-heartbeat as the eventual fallback) and both thresholds
      (`SESSION_REGISTRY_DEAD_PID_MIN`, `SESSION_REGISTRY_REAP_MIN`). *(completed; `pid-alive` and
      `undeterminable` are NEW terminal states this function introduces beyond what
      `cmd_session_reap` alone ever needed, required so `cmd_session_list`/`session_contention`
      have a liveness verdict for every entry, not just reap-worthy ones)*
- [x] Rewrite `cmd_session_reap` to call `session_liveness()` instead of computing inline. Its
      observable output — the `would reap:` / `reaped:` / `SKIP:` lines, the
      `(missing/unparseable entry; age is the file's own mtime)` suffix, the summary lines, and the
      exit code — must be unchanged. *(completed: a corrupt entry's reap decision is re-derived
      from `session_liveness()`'s `corrupt` reason via the same mtime-vs-`SESSION_REGISTRY_REAP_MIN`
      threshold the original inline code used — dead-pid can never fire for a corrupt entry either
      way since it has no pid — and reported with the same `reason=stale-heartbeat` text as
      before, so the printed lines are byte-for-byte identical, not just decision-identical)*
- [x] Add `cmd_session_list`: read-only, no mutation, no `--dry-run` flag (nothing is deleted).
      Globs `specs/.sessions/*.json` (bounded, dedicated-directory scan) and emits one compact
      NDJSON line per entry carrying the raw entry fields plus computed `live` (bool) and
      `liveness_reason` (string). A corrupt/unparseable entry is emitted with
      `liveness_reason: "corrupt"` and `live: true` — never silently dropped. *(completed; `live`
      is derived uniformly as `liveness_reason NOT IN {dead-pid, stale-heartbeat}`, matching D4's
      "live == true, corrupt, and undeterminable-liveness entries DO contend" language exactly)*
- [x] Add the `session-list)` dispatch case and extend the usage string in the `*)` fallback.
      *(completed)*
- [x] Document the new verb in `task-lock.sh`'s own usage/help output. *(completed; the header
      comment's stale "consumed by nothing in the source store today" / "Non-Goal: no reader"
      language was also updated in this same pass — it became false the moment `session-list`
      landed, so leaving it standing until Phase 9's documentation pass would have left this
      script's OWN header self-contradicted for 7 phases)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - `session_liveness()`, `cmd_session_list`, dispatch, usage

**Verification**:
- `bash scripts/test-session-registry.sh` and `bash scripts/test-task-lock-reap.sh` pass UNCHANGED
  (no test edits permitted in this phase — they are the behavior-preservation gate).
- `task-lock.sh session-list` against a fixture `specs/.sessions/` emits valid NDJSON: every line
  parses under `jq -e .`, and every line carries both `live` and `liveness_reason`.
- `task-lock.sh session-list` writes nothing: `specs/.sessions/` is byte-identical before and after.

---

### Phase 3: Add the session-contention rule to the shared library [COMPLETED]

**Goal**: The session-contention rule (D4's three exclusions) exists once, as jq, so neither
consumer re-derives it.

**Tasks**:
- [x] Add `def edge_connected_nums($cnum; $all)` to `FILE_SCOPE_OVERLAP_JQ_DEFS`: returns the set
      of task numbers connected to `$cnum` by a `dependencies[]` edge in EITHER direction, using
      the identical two-clause predicate the existing `comparison_set` construction uses. This is
      a factoring of the existing rule, not a new one. *(completed)*
- [x] Add `def session_contention($cscope; $cnum; $own_sid; $all; $sessions)`: applies D4's three
      exclusions in order (self-session-id, liveness, per-covered-task-number dependency
      exclusion), then applies `scopes_overlap_first` between `$cscope` and each surviving
      session's `file_scope`. Returns the first hit — `{session_id, covered_task_number,
      overlapping_path, liveness_reason}` — or `null` on no hit. *(completed)*
- [x] `covered_task_number` is the LOWEST covered task number that is not itself excluded, per D4.
      *(completed)*
- [x] Session ordering for determinism: sessions are visited in ascending `session_id` string
      order; first hit wins, no exhaustive collection — matching the script's existing
      first-match-wins convention. *(completed; verified with two simultaneously-overlapping
      fixture sessions "sessZ" and "sessAAA" — "sessAAA" wins as expected)*
- [x] Return `null` (never `empty`) on no-hit, for the same reason `self_mod_match` does — the
      result is bound via `as` outside an array comprehension and an `empty` there silently drops
      the whole candidate verdict. *(completed: deviation from the literal task text — the
      no-hit-returns-null property required wrapping the whole filter chain in `[ ... ] | first`,
      i.e. building an actual array then indexing `.[0]`, rather than a bare
      `generator | first // null` pipe. A bare `generator | first` pipes EACH output of the
      generator through `.[0]` individually — an error on a non-array object output, and,
      critically, ZERO outputs (never a `null` fallback) when the generator itself produces zero
      outputs, since there is nothing for `|` to feed into `first` at all. This was caught by the
      Verification harness below, not assumed correct from inspection: it matches the exact
      `[...] | first` idiom `scopes_overlap_first`/`self_mod_match` already use one section above
      in this same file, so the fix converges the code onto the file's own established pattern
      rather than introducing a new one)*
- [x] Add a comment block in the lib stating input 2's semantics explicitly: the session registry
      is the ONLY input carrying its own precomputed, unioned `file_scope`, independent of any
      single task's state.json entry. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - two new jq defs

**Verification**:
- Standalone jq harness: pipe the spliced defs into `jq -n` with hand-built `$sessions` /`$all`
  fixtures and assert each of D4's three exclusions independently — self-session excluded, a
  `stale-heartbeat` session excluded, a `corrupt` session NOT excluded, a fully-edge-connected
  session excluded, a partially-edge-connected session NOT excluded.
- Assert `session_contention` returns JSON `null` (not empty output) on no-hit.
- Both existing task-lock test suites still pass.

---

### Phase 4: Wire the session input into `orchestrate-batch-admit.sh` and bump to v4 [COMPLETED]

**Goal**: Batch admission consults inputs 2 and 3, emitting v4 verdicts, with every existing
defer path unchanged.

**Tasks**:
- [x] Add `--session-id <id>` / `--session-id=<id>` to the argument scan, alongside the existing
      `--invocation-count` handling. Non-empty string; no format validation beyond non-empty.
      *(completed)*
- [x] When `--session-id` is supplied, invoke `task-lock.sh session-list` once and pass the result
      into the jq program via `--slurpfile`/`--argjson`. When omitted, pass an empty session array
      AND print one loud stderr line naming the skip and its consequence (D6 degradation).
      *(completed: deviation from the literal task text — used `jq -s -c` on the piped NDJSON plus
      `--argjson` rather than `--slurpfile`, since `session-list`'s output is a subprocess stdout
      stream, not a file path; `--slurpfile` requires a file argument and has no stdin form)*
- [x] Splice `edge_connected_nums` and `session_contention` from the lib into the program.
      *(completed; both were already part of `$FILE_SCOPE_OVERLAP_JQ_DEFS` as of Phase 3, so no
      separate splice action was needed beyond the existing single splice point)*
- [x] Insert the session pass AFTER the state.json collision scan, reached only when that scan
      found no hit. Emit `defer_reason: "session_active"` with fields `session_id`,
      `colliding_task_number`, `overlapping_path`, `session_liveness_reason`, and a templated
      `reason` string that carries no fact not already present as a structured field. *(completed;
      `colliding_task_number` is `session_contention`'s `covered_task_number`, renamed at the
      verdict-construction boundary to match `file_scope_collision`'s existing field name)*
- [x] Add `corroborated_by` (array of strings) to the existing `file_scope_collision` verdict:
      always contains `"non_terminal_status"`; additionally contains `"session_registry"` when a
      live non-excluded session also covers the colliding task number. Every other field of that
      verdict is unchanged. *(completed: deviation — "non-excluded" is read here as "not the
      caller's own session" plus "live", WITHOUT re-applying D4's edge-connectedness exclusion.
      Rationale: corroboration is evidentiary ("does independent live evidence exist that task
      #N is being worked on"), not a second contention-detection decision, so D4's
      contention-exclusion rules do not gate it — a session fully edge-connected to the CANDIDATE
      can still validly corroborate that the COLLIDING task itself has live work in flight)*
- [x] Change every `"orchestrate-batch-admit-v3"` literal to `"orchestrate-batch-admit-v4"` —
      including the degenerate-candidate and admit branches. *(completed; 10 occurrences)*
- [x] Update the script's header doc block: the v4 field table, the new defer flavor, the
      precedence statement (self_modifying > file_scope_collision > session_active) with D3's
      non-regression invariant stated explicitly, D5's recorded rejection of a held-lock scan with
      the "no repo-wide filesystem walk" reason, and D6's degradation contract. *(completed; the
      script ALREADY carried its own unrelated pre-existing `(D3)`/`(D4)`/`(D5)` labels from an
      earlier task's decision-lettering — `(D3)` = `--invocation-count` co-dispatch scoping,
      `(D4)` = self-mod-runs-first precedence, `(D5)` = critical-path-file degradation. This
      plan's OWN D3 (non-regression invariant) and D5 (held-lock-scan rejection) decisions are
      therefore described in prose without a bare `(D3)`/`(D5)` tag to avoid a silent label
      collision with the file's pre-existing, differently-scoped `(D3)`/`(D5)`; only `(D6)` for
      `--session-id` was safe to tag directly since the file carried no pre-existing D6)*

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts the `"orchestrate-batch-admit-v3"` literal appears only
inside this script's jq program branches and its header. Confirm with
`grep -rn "orchestrate-batch-admit-v3" agent-system/extensions/core/` before editing; any hit in
another script is a consumer pinning the literal and changes Phase 6's scope from
verification to repair. *(Confirmed post-edit: the only remaining hits are in
`docs/architecture/batch-admit-schema.md`, Phase 9's own target — no other script pins the v3
literal, so Phase 6 stays verification-only as hoped.)*

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - flag, session pass, v4, header

**Verification**:
- Non-regression: over the current live candidate set with `--session-id` OMITTED, the NDJSON is
  identical to pre-change output except for the `$schema` string and the added `corroborated_by`
  field. Diff explicitly; do not eyeball.
- With `--session-id` supplied and a fixture session that overlaps a candidate, a
  `defer_reason: "session_active"` verdict is emitted with all five structured fields.
- With `--session-id` set to the fixture session's OWN id, that session does not contend.
- With `--session-id` omitted, the stderr degradation line appears and no session verdict fires.
- Exit code remains 0 regardless of how many verdicts are `defer`.
- Script still never writes to `state.json`.

---

### Phase 5: Wire the session input into `task-lock.sh acquire` [COMPLETED]

**Goal**: Lock acquisition consults all three inputs, with the session pass mirroring the
existing held-lock pass's fresh-ABORT / stale-WARN shape.

**Tasks**:
- [x] In `cmd_acquire`, after the existing held-lock overlap loop and still inside the
      `acquire_scope_mutex` region, add a session-registry pass: call `cmd_session_list` directly
      (same file, no subprocess), read `specs/state.json` once for `$all`, and evaluate
      `session_contention` with the acquiring task's own `session_id` as `$own_sid`. *(completed)*
- [x] On a hit from a `live == true` session: ABORT (return 1) with a message naming the
      overlapping path, the contending session id, the covered task number, and the liveness
      reason — mirroring the existing ABORT message shape and its "wait or coordinate" remedy
      line. *(completed)*
- [x] On a hit from a `corrupt` / `undeterminable` session: ABORT as above, with the liveness
      reason surfaced so the operator can see WHY it was treated as contending. (Per D4's
      conservative direction — never silently drop an unconfirmable session.) *(completed: no
      separate branch was needed — `session_contention()` already applies D4's liveness exclusion
      internally, so EVERY hit it returns is, by construction, from a `pid-alive`, `corrupt`, or
      `undeterminable` session; the single ABORT branch handles all three uniformly, always
      surfacing `liveness_reason` in the message)*
- [x] Confirmed `dead-pid` / `stale-heartbeat` sessions are excluded inside
      `session_contention` and therefore produce no hit at all — no WARN line, no branch here.
      *(completed; verified with a fixture stale-heartbeat session — exit 0, no ABORT)*
- [x] Never mutate the session registry from `cmd_acquire`. Read-only, exactly as the held-lock
      pass never mutates a foreign lock. *(completed; verified with an md5sum before/after the
      overlapping-fixture acquire attempt)*
- [x] Preserve the existing skip conditions verbatim: self-match on task number, same-session
      bypass, unreadable entry. *(completed; the held-lock loop's own skip conditions are
      untouched — the new session pass is a separate, additional block after that loop, not a
      modification to it)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/task-lock.sh` - session pass inside `cmd_acquire`

**Verification**:
- With no `specs/.sessions/` directory at all, `acquire` behaves exactly as before (both existing
  test suites pass unchanged).
- A fixture live session overlapping the acquiring task's scope causes ABORT with exit 1.
- A fixture session whose `session_id` equals the acquirer's does NOT block (same-session bypass).
- A fixture session at a `stale-heartbeat` age does NOT block.
- The session registry is byte-identical before and after every acquire attempt.
- `acquire_scope_mutex` is still released on every return path (the `trap ... RETURN` still covers
  the new branch).

---

### Phase 6: Verify v4 inheritance in the downstream composers [COMPLETED]

**Goal**: Confirm — empirically, not by precedent — that the composers inherit the converged
predicate, and surface the new evidence in their human-readable output.

**Tasks**:
- [x] Re-verify that `orchestrate-predispatch-review.sh` and `orchestrate-dry-run-report.sh` pin
      no `$schema` string literal and branch on `defer_reason` rather than assuming a fixed set.
      Do NOT inherit the v2→v3 "survived unedited" note as an assumption — run each against a live
      NDJSON stream containing a `session_active` verdict and confirm the verdict is neither
      dropped nor mis-bucketed. *(completed — and this empirical run FOUND A REAL BUG, not a
      clean pass: `orchestrate-predispatch-review.sh` pinned no `$schema` and was safe as-is
      (Classes C/D `select()` on a specific `defer_reason` value, so an unrecognized third value
      simply matches neither — inert, not mis-bucketed). `orchestrate-dry-run-report.sh` was
      NOT safe: its defer_reason handling checked `self_modifying` explicitly, then FELL THROUGH
      unconditionally into file_scope_collision field reads with no `session_active` branch. A
      `session_active` verdict has `.collision_scope` absent (reads as `""`, never
      `"cross_batch"`), so it fell into the `else` arm and was mis-bucketed as an in-batch
      wave-deferral NOTE rather than the EXCLUSION it actually is — silently under-reporting a
      real exclusion in the dry-run report, exactly the risk this task's own risk table named.
      Fixed with an explicit `session_active` branch inserted before the fallthrough; verified
      empirically both without `--session` (dimension degrades, candidate correctly stays
      admitted) and with `--session` (verdict correctly appears as an Excluded entry, confirmed
      by a live fixture run — see the fork's verification output above this plan edit).)*
- [x] Check `orchestrate-triage-classify.sh`, which also references `orchestrate-batch-admit.sh` —
      determine whether it consumes verdicts (and therefore needs the same verification) or only
      names the script in prose. *(completed: confirmed a mere prose reference — it never
      subprocess-calls `orchestrate-batch-admit.sh` and has its own independent, unrelated
      `orchestrate-triage-v1` schema. Out of scope; no changes made.)*
- [x] Add an optional `--session-id <id>` passthrough to both composers, forwarded verbatim to
      their `orchestrate-batch-admit.sh` subprocess call alongside the existing
      `--invocation-count`. When their own caller supplies none, the degradation line from D6
      surfaces — which is the honest outcome, not a defect. *(completed with a deviation for
      `orchestrate-predispatch-review.sh`: that script already had a PRE-EXISTING `--session-id`
      flag for an unrelated purpose — `state-write.sh` mutex attribution under `--repair` — that
      auto-generates a fallback id when omitted. Forwarding that fallback unconditionally would
      have activated batch-admit's session pass with a session id that was never actually
      registered (a pointless, misleading self-exclusion key), so a new `session_id_explicit`
      flag tracks whether the CALLER actually supplied `--session-id`; only then is it forwarded.
      `orchestrate-dry-run-report.sh`'s existing `--session` flag had no such fallback, so it
      forwards directly whenever non-empty. Also forwarded to
      `orchestrate-predispatch-review.sh`'s OWN subprocess call from within
      `orchestrate-dry-run-report.sh`'s Step 8, so the chain (`dry-run-report` ->
      `predispatch-review` -> `batch-admit`) carries the same session id end-to-end.)*
- [x] Extend each composer's per-verdict note templating to render the `session_active` flavor and
      the `corroborated_by` array, following each file's existing note-composition style.
      *(completed: `orchestrate-predispatch-review.sh` gained a new Class E section mirroring
      Class D's shape (report-only, "0 findings" when empty, `SKIPPED` when degraded OR when
      `--session-id` was not supplied); `orchestrate-dry-run-report.sh`'s Excluded-section
      `session_active` branch (added above) and its existing `file_scope_collision` branch both
      render `corroborated_by`/`session_liveness_reason` inline in the reason string.)*
- [x] Where either composer's prose describes "two defer flavors", update to three. *(N/A — grep
      confirmed neither file's prose used that literal phrasing; the header doc blocks were
      still updated to describe the new session_active/Class E dimension explicitly, achieving
      the same documentation goal by a different literal path.)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: this phase assumes exactly two composers consume batch-admit NDJSON.
`grep -rn "orchestrate-batch-admit.sh" agent-system/extensions/core/scripts/` lists a third
script (`orchestrate-triage-classify.sh`); classify it as consumer or mere reference before
closing the phase, and expand the phase's file list if it consumes verdicts. *(Confirmed: exactly
two consumers. `orchestrate-triage-classify.sh` only mentions batch-admit's exit-code convention
in a comment and never subprocess-calls it — mere reference, file list unchanged.)*

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - passthrough, note templating
- `agent-system/extensions/core/scripts/orchestrate-dry-run-report.sh` - passthrough, note templating
- (conditional) `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` - if it consumes verdicts

**Verification**:
- Each composer run against a fixture NDJSON containing one verdict of each of the three defer
  flavors renders all three; none is silently dropped.
- Each composer's pre-existing output for a v3-shaped input set is unchanged apart from the new
  evidence text.
- Both composers still exit with their documented codes.

---

### Phase 7: Extend batch admission to the plain multi-task command paths (Gap C) [COMPLETED]

**Goal**: `/research N,M`, `/plan N,M`, `/implement N,M` gain the batch-admission pre-check they
lack today.

**Tasks**:
- [x] In each of `commands/research.md`, `commands/plan.md`, `commands/implement.md`, locate the
      anchor: immediately AFTER the `task-lock.sh session-register` call, BEFORE the per-task
      `task-lock.sh acquire` loop. Anchor on the quoted `session-register` and `acquire` command
      strings, never on line numbers. *(completed; the anchor shape was structurally identical in
      all three files as the Scope Hypothesis predicted — inserted as a new "Step 2.5: Batch
      Admission Pre-Check (Gap C)" subsection between the existing "Step 2" and "Step 3" headings
      in each file)*
- [x] Insert one `orchestrate-batch-admit.sh` call per invocation for the whole validated set,
      passing `--invocation-count "${#validated_tasks[@]}"`, `--session-id "$batch_session_id"`,
      and the validated task numbers positionally. *(completed; functionally verified against a
      live fixture for both research.md's and plan.md's exact bash shape)*
- [x] Move every `decision == "defer"` task out of `validated_tasks` BEFORE the acquire loop runs,
      using **each file's own existing bucket-naming convention verbatim** — `plan.md` names both
      `skipped_tasks` and `invalid_tasks` in its per-task-acquire-refusal text while
      `research.md` and `implement.md` name only `skipped_tasks`. Do not assume uniformity; read
      each file's convention and follow it. *(completed: plan.md's PROSE loosely says
      "skipped_tasks/invalid_tasks" but its actual declared bash array (Step 1) is `invalid_tasks`
      only — followed the real variable, not the loose prose. research.md and implement.md both
      use `skipped_tasks`.)*
- [x] Mirror the existing `"locked by another session"` skip-reason phrasing style for the new
      skip reasons, carrying the verdict's `defer_reason` so the operator can tell the three
      flavors apart. *(completed: `"$t: deferred by batch admission [$defer_reason]"` for the
      array entry, mirroring the existing `"$task_num: terminal status [$status]"` bracket
      convention already used in each file's own Step 1, plus a fuller `[WARN]` stderr line
      carrying the verdict's full `reason` text)*
- [x] Leave the per-task acquire loop's own semantics completely unchanged — an admitted candidate
      still goes through per-task locking exactly as today. *(completed; Step 3 in all three
      files is untouched)*
- [x] EXCLUDE, NEVER AUTO-EXPAND: a deferred task is dropped from this invocation. Never pull an
      out-of-batch predecessor in. *(completed; the filtering loop only ever rebuilds
      `validated_tasks` as a subset of itself)*
- [x] Confirm `commands/orchestrate.md` already calls batch-admit (it is not part of Gap C); if it
      does not yet pass `--session-id`, add it there too for consistency with D6. *(completed with
      a significant discovery beyond the literal task text: `commands/orchestrate.md`'s own
      bash block is explicitly documented, in its OWN surrounding prose, as "illustrative of the
      CONTRACT skill-orchestrate fulfills, not code this file itself runs" — the REAL, EXECUTING
      call lives in `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` Stage MT-3
      step 4.5 (line ~1391), which also did NOT pass `--session-id`. Updated BOTH: the
      illustrative block in `commands/orchestrate.md` (so the illustration stays accurate) and
      the real call in `skill-orchestrate/SKILL.md` (so `/orchestrate`'s actual dispatch path
      gets the D6 fix, not just its documentation). Additionally discovered that NEITHER file's
      `defer_reason` branching prose covered `session_active` at all — both enumerated only
      `self_modifying` and `file_scope_collision` with no third branch and no fallback, which for
      `skill-orchestrate/SKILL.md` (the REAL dispatch decision logic, not a report composer) meant
      a `session_active` verdict would match neither branch and the candidate would likely
      dispatch anyway, silently defeating the new input entirely on the one path that actually
      acts on verdicts rather than just reporting them. Added a third `session_active` bullet,
      mirroring the existing two branches' shape (remove from dispatch batch, distinct warning,
      `defer_ledger` entry), to both `commands/orchestrate.md`'s illustrative prose and
      `skill-orchestrate/SKILL.md`'s real Stage MT-3 step 4.5 logic. This expands the phase's
      actual file list by one beyond what was declared (see Files to modify below) — a scope
      expansion analogous to Phase 6's dry-run-report.sh fallthrough-bug discovery, made for the
      same reason: an unbranched defer_reason on the one path that ACTS on verdicts is a
      correctness bug, not a documentation nicety.)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts the anchor shape (`session-register` immediately followed
by the dispatch step whose item 3 is the per-task `acquire`) is structurally identical in all
three command files. Confirm per file before editing; if one diverges, follow that file's actual
structure rather than forcing the common shape.

**Files to modify**:
- `agent-system/extensions/core/commands/research.md` - batch-admit call at the anchor
- `agent-system/extensions/core/commands/plan.md` - same, with that file's own bucket naming
- `agent-system/extensions/core/commands/implement.md` - same
- `agent-system/extensions/core/commands/orchestrate.md` - `--session-id` consistency and
  `session_active` branch on its illustrative block (not part of Gap C proper)
- (discovered during implementation, not pre-declared) `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  - the REAL executing counterpart to `commands/orchestrate.md`'s illustrative block: Stage MT-3
    step 4.5's `orchestrate-batch-admit.sh` call gains `--session-id "$session_id"` and a new
    `session_active` defer_reason branch, without which `/orchestrate`'s actual dispatch path
    would never have benefited from this convergence at all

**Verification**:
- Each of the three files contains exactly one new `orchestrate-batch-admit.sh` invocation,
  positioned between the `session-register` call and the acquire loop.
- Each invocation passes all three of `--invocation-count`, `--session-id`, and positional task
  numbers.
- No file's per-task acquire loop text changed.
- Bucket names used in each file match that file's pre-existing convention (verify by grepping
  each file for its own bucket variable names).

---

### Phase 8: Test suite for the converged predicate [COMPLETED]

**Goal**: An isolated-temp-root suite pinning every decision above, so the convergence cannot
silently regress.

**Tasks**:
- [x] Create `agent-system/extensions/core/scripts/test-conflict-predicate.sh` following the
      isolated-temp-root precedent of `test-task-lock-reap.sh` / `test-session-registry.sh`:
      throwaway `$TMPROOT` satisfying `deploy-root-guard.sh`, real scripts copied byte-for-byte
      (no testability hooks added to production code), fixture `state.json` and
      `specs/.sessions/` entries at controlled ages, `pass`/`fail`/`info` helpers, cleanup trap,
      controlled-epoch timestamps with no sleeping. Exit 0 on all-pass, 1 on any fail. *(completed;
      23 cases across 8 groups, all passing)*
- [x] **Overlap parity cases**: the lib's bash `scopes_overlap()` and its spliced
      `scopes_overlap_first` return the same answer on the same inputs — exact match, either-side
      directory-prefix, trailing-slash normalization, no-overlap, empty scope, null scope.
      *(completed: Group 1, cases 1.1-1.6)*
- [x] **Bit-for-bit preservation cases**: `in_batch` defers only against a LOWER `project_number`;
      `cross_batch` defers unconditionally; a dependency edge in either direction excludes the
      pair entirely; self-modification runs first and short-circuits the collision scan.
      *(completed: Group 2, cases 2.1-2.4. Required an isolated-scope-namespace-per-group fixture
      redesign mid-implementation — an initial fixture sharing one `file_scope` string
      ("path/a.sh") across candidates from DIFFERENT test groups caused cross-contamination: a
      candidate's session-only test would spuriously collide via the STATE.JSON scan against an
      unrelated group's fixture entry, since every non-terminal task sharing a scope string is a
      real comparison target regardless of which group "owns" it. Fixed by giving each group its
      own scope namespace (`g21/`, `g22/`, `g23/`, `g4/`).)*
- [x] **Non-regression case**: a fixture state producing a `file_scope_collision` defer yields a
      verdict identical to the pre-change v3 shape apart from `$schema` and `corroborated_by`.
      *(completed: Group 3)*
- [x] **Session-input cases**: live session contends; `dead-pid` does not; `stale-heartbeat` does
      not; `corrupt` DOES; own-`session_id` does not; a session covering only edge-connected task
      numbers does not; a session covering one edge-connected and one unrelated number DOES.
      *(completed: Group 4, cases 4.1-4.7. The `corrupt` DOES case (4.4) required a DIFFERENT test
      level than the other six: a REAL corrupt session-registry entry is structurally unable to
      carry `file_scope` data at all (unparseable JSON means nothing can be safely read from it,
      so `session-list` forces `file_scope: []`), so it can NEVER produce an actual overlap hit
      through the full `session-list` -> `orchestrate-batch-admit.sh` integration path regardless
      of whether the liveness exclusion correctly admits it — that emptiness is a property of
      "corrupt data is unreadable", not of the exclusion logic under test. Retargeted 4.4 to call
      `session_contention()` directly via a jq harness with a hand-built session object carrying
      `liveness_reason: "corrupt"` AND a real `file_scope`, isolating exactly the exclusion-logic
      claim D4 makes, matching the verification approach already used ad hoc during Phase 3.)*
- [x] **Degradation cases**: `--session-id` omitted skips the session input and prints the stderr
      line; a missing `specs/.sessions/` directory is not an error. *(completed: Group 5)*
- [x] **`session-list` cases**: valid NDJSON, `live`/`liveness_reason` on every line, corrupt entry
      emitted rather than dropped, registry unmodified after the call. *(completed: Group 6)*
- [x] **Fail-closed case**: with the lib absent, both consumers exit 2 with a message naming the
      remedy — never a silently skipped overlap check. *(completed: Group 7. Required pointing the
      fail-closed fixture invocations at a candidate with a genuinely non-empty declared
      `file_scope`, since `task-lock.sh`'s lazy `ensure_file_scope_overlap_lib()` gate (Phase 1's
      deviation) is only reached when `own_scope` is non-empty — a candidate with no declared
      scope would silently skip the lib-load attempt entirely and falsely appear to pass.)*
- [x] Confirm the new test file reaches the deployed tree, per the same loader-copy check Phase 1
      performed. *(completed with a significant discovery beyond the literal task text: the
      "known extension-loader gap" this plan's Risks table and D1 decision cited as an
      unresolved, undiagnosed limitation is NOT actually an inherent property of "new files under
      an already-loaded extension" — it is caused by the new file being absent from the core
      extension's `manifest.json` `provides.scripts` array. `check-extension-docs.sh` surfaced
      this directly: both `scripts/lib/file-scope-overlap.sh` (Phase 1) and
      `scripts/test-conflict-predicate.sh` (this phase) were flagged as "on disk NOT in
      provides.scripts". Adding both entries to `agent-system/extensions/core/manifest.json` and
      re-running `deploy-headless.sh` (no manual copy step) deployed BOTH files correctly on the
      very next headless sync — the manual one-off copies performed at Phase 1 and earlier in
      this phase were a genuine, working workaround for the SYMPTOM, but the manifest fix here is
      the actual root-cause repair. This is left recorded here rather than generalized into a
      rewrite of the "known gap" language in `.claude/rules/no-task-references-in-deliverables.md`'s
      "Known gap" section or the D1 decision record above — those documents describe a
      genuinely-observed prior symptom accurately; whether EVERY historical instance of "a new
      script never reached the deployed tree" traces to a missing manifest entry specifically, as
      opposed to some other contributing cause, is not verified here and is out of this task's
      scope to audit repo-wide.)*

**Timing**: 2 hours

**Depends on**: 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` - NEW
- (discovered during implementation, not pre-declared) `agent-system/extensions/core/manifest.json`
  - `provides.scripts` gained `lib/file-scope-overlap.sh` and `test-conflict-predicate.sh` —
    root-cause fix for the loader-copy gap Phase 1 and this phase both worked around with a
    manual one-off copy

**Verification**:
- `bash scripts/test-conflict-predicate.sh` exits 0 with every case PASS. *(confirmed: 23 passed,
  0 failed)*
- The real `specs/` tree is untouched by a full run (`git status --porcelain specs/` empty).
  *(confirmed — the only `specs/` diffs present are this task's own pre-existing in-flight
  status/plan-edit churn, unrelated to the test run)*
- `test-task-lock-reap.sh`, `test-session-registry.sh`, `test-session-runtime-files.sh`, and
  `test-state-write-concurrency.sh` all still pass. *(confirmed, all four green)*
- Additionally run beyond the literal checklist: `bash .claude/scripts/verify-deploy.sh` and
  `bash .claude/scripts/check-extension-docs.sh` — both confirm `core` extension PASS after the
  manifest fix; the sole remaining `verify-deploy.sh` failure is the pre-existing, unrelated
  `literature` extension `.pyc`-cache-and-undeployed-scripts issue documented in a prior task's
  summary, not introduced by this work.

---

### Phase 9: Converge the documentation set [COMPLETED]

**Goal**: Four documents describe ONE predicate over three explicitly-asymmetric inputs, with no
document left contradicted.

**Tasks**:
- [x] `context/patterns/file-footprint-overlap.md`: rewrite the Lock-acquisition-level and
      Batch-admission-level Consumers bullets to say both call the ONE shared implementation
      (`scripts/lib/file-scope-overlap.sh`) rather than each carrying its own transcription. Add a
      session-registry application bullet, worded the way the self-modification bullet already is
      ("a further application of this same predicate, not a new matching rule"). Update the
      closing "All four callers reference this document by path" sentence to the new count.
      *(completed)*
- [x] `context/patterns/file-footprint-overlap.md`: add a section stating the THREE contention
      inputs and their asymmetric semantics explicitly — (1) held locks are a liveness/confidence
      signal that supplies no scope of its own (`holder.json` carries no `file_scope`; the other
      side's scope is always re-fetched from state.json); (2) the session registry is the only
      input carrying its own precomputed, unioned scope, independent of any single task's
      state.json entry; (3) non-terminal state.json tasks are the broadest but least live signal.
      Record D5's rejection of a held-lock scan in batch-admit with its reason. *(completed as
      "## Three Contention Inputs")*
- [x] `context/patterns/task-lock.md`: REPLACE the "Non-Goal: No Reader" section with the reader's
      contract — the registry now has exactly one reader shape (`session-list`), which carries its
      own freshness computation via `session_liveness()`, and its consumers apply their own
      exclusion rules. Leaving the Non-Goal standing would leave the document contradicted.
      Document the `session-list` subcommand alongside the existing Session-Registry CLI verbs.
      *(completed; also added a `### session_liveness()` subsection documenting the shared
      two-signal computation, and extended the "Consumers (Five Distinct Wiring Paths)" section
      with a new item 6 for the `session-list` reader call sites)*
- [x] `docs/architecture/batch-admit-schema.md`: bump to v4; add the full field table for the
      three defer flavors including `corroborated_by`, `session_id`, and
      `session_liveness_reason`; write the "v3 to v4" Version History entry mirroring the two
      existing entries' structure, including the "every in-repo consumer's status as of v4" table
      populated with the Phase 6 verification RESULTS (not assumptions). Document `--session-id`
      and D6's degradation contract. Re-examine and update the "A1 — dependency-edge exemption
      asymmetry" section for the session dimension, recording D4's per-covered-task-number rule
      and why it differs from the self-modification dimension's absent exemption. *(completed with
      one discovery beyond the literal task text: writing the v4 consumer table surfaced that
      `skill-orchestrate-hard/SKILL.md`'s explicitly CO-MAINTAINED transcription of Stage MT-3 step
      4.5 had NOT received the `--session-id`/`session_active` fix Phase 7 applied to the base
      `skill-orchestrate/SKILL.md`. Fixed it here — per that file's own "an edit to either copy
      REQUIRES the same edit to the other" mandate — rather than merely recording it as a declared
      residual, so `/orchestrate --hard` does not retain the exact fatal-self-block gap this whole
      task exists to close.)*
- [x] `context/patterns/batch-orchestration-guardrails.md`: the named scan-scope gap ("a task that
      is neither in this invocation's set nor currently holding a lock is invisible to all three
      simultaneously") is now narrowed, not eliminated — update the passage to state precisely
      what the third input closes and what remains open (a task with no lock, no live session, and
      a terminal status is still invisible, by design). Do not claim more closure than was
      achieved. *(completed: added an explicit "FIFTH... input narrows this gap further, without
      eliminating it" paragraph, stating precisely that a genuinely idle NON-terminal task remains
      visible via the pre-existing state.json scan regardless of this change — the session
      registry adds one more live signal, it does not change what state.json already made
      visible — and that the residual invisible case is specifically a TERMINAL-status task,
      excluded from all inputs' scans by design)*
- [x] Verify no deliverable outside `specs/**` cites a task number: run
      `bash .claude/scripts/check-task-references.sh`. *(completed: PASS, 0 unexempted occurrences
      across all 4 scanned trees)*

**Additional file touched, beyond the four declared above**: `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
— see the batch-admit-schema.md task note above; required by that file's own co-maintenance
mandate with `skill-orchestrate/SKILL.md`, which Phase 7 had already updated.

**Timing**: 1.5 hours

**Depends on**: 8

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- `agent-system/extensions/core/context/patterns/task-lock.md`
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- (discovered during implementation, not pre-declared) `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`

**Verification**:
- `grep -rn "Non-Goal: No Reader" agent-system/extensions/core/` returns nothing. *(confirmed)*
- `grep -rn "orchestrate-batch-admit-v3" agent-system/extensions/core/` returns hits only inside
  the Version History section of the schema doc. *(confirmed — actually returns ZERO hits: every
  JSON example was bumped to v4 and the Version History prose only uses the bare word "v3", never
  the full dashed literal)*
- No document still describes two separate transcriptions of the overlap algorithm. *(confirmed)*
- `bash .claude/scripts/check-task-references.sh` exits 0. *(confirmed PASS)*
- Cross-reference check: every path named in the four documents resolves to a real file.
  *(confirmed for every path introduced or touched by this phase's edits)*
- Additionally run beyond the literal checklist: `bash .claude/scripts/deploy-headless.sh` +
  `bash .claude/scripts/check-extension-docs.sh` — `core` extension PASS after every Phase 9 doc
  edit; the full `test-conflict-predicate.sh` / `test-task-lock-reap.sh` /
  `test-session-registry.sh` / `test-session-runtime-files.sh` /
  `test-state-write-concurrency.sh` suite re-run clean (documentation-only phase, but re-verified
  nothing regressed).

---

## Testing & Validation

- [x] `bash scripts/test-conflict-predicate.sh` exits 0 (new suite, Phase 8). *(23/23 passed)*
- [x] `bash scripts/test-task-lock-reap.sh` exits 0 (unchanged behavior gate). *(6/6 passed)*
- [x] `bash scripts/test-session-registry.sh` exits 0 (unchanged behavior gate). *(10/10 passed)*
- [x] `bash scripts/test-session-runtime-files.sh` and `bash scripts/test-state-write-concurrency.sh` exit 0.
      *(6/6 and 4/4 passed respectively)*
- [x] `bash scripts/verify-deploy.sh` passes, including gate 4 (`check-task-references.sh`).
      *(gate 4 — task-reference lint — PASSES. The overall script exits non-zero solely on gate 3's
      doc-lint sub-check, which fails ONLY on the pre-existing, unrelated `literature` extension
      `.pyc`-cache/undeployed-scripts issue documented in a prior task's summary; the `core`
      extension's own doc-lint status is PASS after this task's manifest.json fix.)*
- [x] `bash .claude/scripts/check-extension-docs.sh` exits 0. *(same caveat as above: `core` PASSes
      cleanly; the script's overall exit code reflects the pre-existing, unrelated `literature`
      extension failure, not anything this task touched.)*
- [x] Non-regression diff: `orchestrate-batch-admit.sh` output over the live candidate set with
      `--session-id` omitted differs from the pre-change baseline only in `$schema` and
      `corroborated_by`. *(confirmed via automated field-by-field diff in Phase 4)*
- [x] `specs/` tree untouched by any test run. *(confirmed — every isolated-temp-root suite cleans
      up its own `$TMPROOT`; the only `specs/` diffs present throughout implementation are this
      task's own pre-existing in-flight status/plan-edit churn)*
- [x] Deployed-tree reachability confirmed for `scripts/lib/file-scope-overlap.sh` and
      `scripts/test-conflict-predicate.sh`. *(confirmed — both now deploy correctly via a plain
      `deploy-headless.sh` run with no manual copy step, following the manifest.json fix recorded
      in Phase 8)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (new)
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (new)
- Modified: `task-lock.sh`, `orchestrate-batch-admit.sh`, `orchestrate-predispatch-review.sh`,
  `orchestrate-dry-run-report.sh`, and conditionally `orchestrate-triage-classify.sh`
- Modified: `commands/research.md`, `commands/plan.md`, `commands/implement.md`,
  `commands/orchestrate.md`
- Modified: `context/patterns/file-footprint-overlap.md`,
  `context/patterns/task-lock.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `docs/architecture/batch-admit-schema.md`
- Verdict schema at `orchestrate-batch-admit-v4`

## Rollback/Contingency

Every phase is a self-contained commit against `agent-system/extensions/core/**`; no phase writes
to `specs/state.json` or mutates any lock or session entry, so rollback is a plain `git revert` of
the phase commits in reverse order followed by a redeploy.

Two specific contingencies:

- **If the deployed-tree reachability check in Phase 1 fails and cannot be resolved**, stop before
  Phase 2. A `task-lock.sh` that cannot source its lib fails closed and blocks all task locking in
  the deployed tree. Reverting Phase 1 restores the two inline transcriptions, which is a working
  (if unconverged) state.
- **If Phase 6 finds a composer that DOES pin the `$schema` literal or assumes a closed
  `defer_reason` set**, that composer's repair becomes part of Phase 6 rather than a deferred
  follow-up — shipping v4 with a consumer that silently drops verdicts is worse than not shipping
  the third input at all.
