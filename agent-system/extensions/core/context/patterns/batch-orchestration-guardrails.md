# Batch Orchestration Guardrails

This file documents the *principles* that govern admission control for batched `/orchestrate`
invocations — when a guardrail must block dispatch, when it may merely warn, and how both answers
should change (or not change) as batch size grows. The *mechanisms* that implement these
principles already exist and are documented elsewhere; this file cross-references them by path
rather than restating their algorithms. This file defines no new behavior and changes no
skill, command, script, or agent file.

## The Three Existing Admission Layers

Batch admission control in this system is not a single check but three layers, each with a
different scan scope, that together approximate a combined optimistic-pre-check-plus-pessimistic-lock
concurrency strategy:

1. **Creation-time** — the pairwise directory-prefix overlap algorithm defined in
   `file-footprint-overlap.md` is run once across a batch of tasks proposed together at creation
   time, and a serializing `dependencies[]` edge is auto-added for every overlapping pair with no
   existing edge. Scan scope: the creation batch only.
2. **Runtime wave/cycle-split check** — before dispatching any wave or cycle containing 2+ tasks,
   the same overlap algorithm is re-applied to every pair already collected into *this
   invocation's* task set. On overlap with no `dependencies[]` edge, the lower-priority task
   (higher project number) is deferred to a later wave/cycle — never failed. Scan scope: this
   invocation's task set only.
3. **Lock-acquisition-time** — at per-task lock acquire, the acquiring task's `file_scope` is
   compared against every *other currently-held* lock's `file_scope`, repo-wide. A fresh
   overlapping foreign lock causes refusal; a stale one warns and proceeds. Scan scope: every
   currently-held lock, repo-wide.

A fourth, orthogonal dimension is layered on top of the batch-admission layer (layer 2's
cross-batch extension, `orchestrate-batch-admit.sh`): the **self-modification hazard** check. It
is not a new scan scope — it reuses layer 2's existing single-`specs/state.json`-read admission
call — but a different *predicate* evaluated on the same candidate before the pairwise overlap
scan runs at all: does the candidate's own `file_scope` name an orchestrator-critical file? See
"Self-Modification Hazard: The Fourth Admission Dimension" below for the full rationale.

Layers 1-2 are a cheap, no-agent-invoked, optimistic pre-check: they decide whether to even
attempt concurrent dispatch. Layer 3 is a pessimistic enforcement lock: it is the mutex that
actually prevents two concurrent writers. The layers are independently sound, but their scan
scopes do not overlap perfectly — a task that is neither in this invocation's set nor currently
holding a lock is invisible to all three simultaneously. Closing that gap is a scan-scope
question, addressed under Non-Negotiables and the Open Design Fork below, not a new-check
question.

## Blocking vs. Advisory: The Criterion

A guardrail is **BLOCKING** — refuse to dispatch, i.e. defer — if and only if **both** of the
following hold:

1. It is computable purely from on-disk structural state, without invoking any agent.
2. The harm of proceeding anyway is silent and hard to detect after the fact (concurrent file
   corruption, acting on stale context, an unmet dependency treated as satisfied).

A guardrail is **ADVISORY** — warn, then continue — when either of these fails: the underlying
signal is inherently a heuristic or estimate rather than a hard fact, or the condition being
flagged is not this invocation's to fix. Advisory never means unlogged or silent; every advisory
signal must still surface a visible warning.

This is a conjunction of two conditions, not a single cost condition. A check that is cheap but
whose signal is a heuristic (for example, a drift-percentage estimate) is still advisory. A check
that is expensive but structural and silently-harmful if skipped is still blocking; cost alone
never demotes a check to advisory.

### Classification Table

| Guardrail | Classification | Why |
|---|---|---|
| File-scope overlap (creation-time and runtime wave/cycle-split) | BLOCKING | On-disk `file_scope` comparison, no agent invoked; an unserialized overlap risks silent concurrent-write corruption discovered only later |
| Held lock (lock-acquisition-time) | BLOCKING | On-disk lock state, no agent invoked; proceeding past a live lock risks the same silent corruption |
| Unmet predecessor (dependency-graph eligibility) | BLOCKING | On-disk dependency edge and terminal-status check, no agent invoked; treating an unmet dependency as satisfied is silent and hard to detect after the fact |
| Self-modification hazard (candidate `file_scope` names an orchestrator-critical path) | BLOCKING | Computable from the candidate's own on-disk `file_scope` against a fixed, declared critical-path list — no agent invoked; the harm (an unverifiable orchestrator-machinery fix committed automatically as part of a multi-task dispatch) is silent and hard to attribute later, satisfying both halves of the criterion |
| Heuristic drift-percentage signal | ADVISORY | The signal is an estimate from a fork's plan inspection, not a hard fact — fails condition 1's structural-fact requirement in spirit even though it reads on-disk state, because the *derived* percentage is inherently approximate |
| Absent completion-marker verification signal (`plan_markers_verified` missing or false) | ADVISORY | Per the handoff schema's own documented behavior, this warns but does not block the next lifecycle phase — the condition is logged, not gated, because it is deliberately designed as a non-blocking signal |

## Self-Modification Hazard: The Fourth Admission Dimension

A candidate task whose declared `file_scope` names a file that is itself part of the orchestrator
machinery — the dispatch loop, the admission predicate, the lock, the status gatekeeper — poses a
qualitatively different hazard than an ordinary file-scope collision: the running session that
would admit, commit, and grade that fix is the very machinery the fix changes. This section
records the two tests used to decide which files belong on that list, not merely today's answer,
so a future reader can judge a *newly proposed* file rather than pattern-match on the names below.

### The Two Conjunctive Tests

A file belongs on the critical-path list if and only if **both** hold:

1. **Reachability** — the file is actually read or executed on the MULTI-TASK batch-dispatch
   path. Single-task `/orchestrate` never has siblings to worry about, so a file that is only
   reachable there is out of scope for this specific gate (it may still be sensitive for other
   reasons, but this gate exists to protect *concurrent, batched* dispatch).
2. **Decision-relevance** — a defect in the file yields a silent WRONG admission, wave, lock, or
   completion decision, not a loud failure and not a merely cosmetic one. A file that would fail
   loudly (aborting the run) or that only affects reporting/formatting fails this test even if it
   is reachable.

Both tests must hold. A file that is reachable but not decision-relevant, or decision-relevant
but not reachable from MT dispatch, is excluded.

### Inclusion Table (the nine files, with per-file evidence)

| # | Path (relative to the core extension root) | Reachability evidence | Decision-relevance evidence |
|---|---|---|---|
| 1 | `skills/skill-orchestrate/SKILL.md` | The multi-task dispatch state machine itself — Stages MT-1 through MT-5 ARE the MT batch-dispatch path | A defect here silently mis-routes eligibility, wave/cycle admission, or postflight status — the core decision surface |
| 2 | `skills/skill-orchestrate-hard/SKILL.md` | Hard-mode inherits and extends MT-1..MT-5 for `/orchestrate --hard` batch runs | Same class of silent mis-routing risk as #1, scoped to the hard-mode contract layer |
| 3 | `commands/orchestrate.md` | The command entry point that builds the wave schedule and invokes the admission predicate for MT dispatch (Step 3) | A defect silently changes which wave a task lands in, or skips the admission call entirely |
| 4 | `scripts/skill-base.sh` | Sourced by preflight/postflight for every dispatched task in a batch | A defect silently corrupts the preflight/postflight/completion-claim gate for every task in the batch, not just one |
| 5 | `scripts/task-lock.sh` | Acquired/released per task inside MT dispatch (Stage MT-4) | A defect silently breaks the concurrency mutex itself — the last line of defense against two tasks writing the same files |
| 6 | `scripts/update-task-status.sh` | Invoked by postflight for every task a batch dispatches | A defect silently writes a wrong status transition, corrupting `state.json` for the whole batch |
| 7 | `scripts/orchestrate-batch-admit.sh` | THE admission predicate this gate itself extends; called once per wave/cycle | A defect here is maximally silent: it IS the mechanism deciding admission, so a bug in it defeats the very check meant to catch bugs like it |
| 8 | `scripts/orchestrate-triage-classify.sh` | Called once per MT cycle (Stage MT-4) to route tasks to research/plan/implement | A defect silently misroutes a task to the wrong lifecycle phase |
| 9 | `scripts/orchestrate-dry-run-report.sh` | Composes the `--dry-run` report human operators trust to preview a live run | A defect silently misrepresents what a live run would actually do, undermining the one human-facing verification surface for batch composition |

### Exclusion Table (explicitly excluded, with evidence)

**Excluded on the skill's own explicit statement / zero-reference grep** (fails reachability):

| Path | Evidence |
|---|---|
| `scripts/command-gate-in.sh` | `skills/skill-orchestrate/SKILL.md` states explicitly that MT dispatch never sources the single-task gate-in/gate-out scripts — the MT path has its own Stage MT-1/MT-2 initialization instead |
| `scripts/command-gate-out.sh` | Same explicit statement as above — MT dispatch never sources it |
| `scripts/orchestrator-postflight.sh` | Zero references anywhere in `skills/skill-orchestrate/SKILL.md` (confirmed by grep at authoring time) — this script belongs to a different command's postflight, not MT dispatch |

**Reachable but not decision-relevant** (fails decision-relevance — these files are read on the
MT path but a defect in them fails loudly or is merely cosmetic, not a silent wrong decision):

| Path | Evidence |
|---|---|
| `scripts/generate-todo.sh` | Regenerates the human-facing `TODO.md` view from `state.json` — a defect produces a visibly wrong rendered file, not a silent wrong admission/wave/lock/completion decision |
| `scripts/validate-artifact.sh` | Validates artifact format/presence — a defect fails loudly (a validation error) rather than silently corrupting a scheduling decision |
| `scripts/lifecycle-notify.sh` | A notification/logging hook — a defect at worst drops or garbles a notification; it does not feed back into any admission, wave, lock, or completion decision |

### The Deploy-Manual Analysis and the Surviving Hazards

The research behind this gate initially hypothesized that a source-store edit to orchestrator
machinery could corrupt the *currently running* session. That hypothesis does not hold: this
repository's core extension deploys manually (a human runs `<leader>al` / "Load Core" to
regenerate `.claude/` from `agent-system/extensions/core/`), so a source-store edit cannot alter
a session already in flight. That reversal does not cancel the gate — it redefines what the gate
actually protects. Of the three hazards this reasoning originally identified, hazard 2 below is
now **RETIRED**; hazards 1 and 3 remain live and are the actual, surviving rationale for keeping
this gate:

1. **Verification-gap risk** (live) — a fix to orchestrator machinery is necessarily verified only
   against a scratch deploy-tree copy (per this plan's own SOURCE-STORE RULE), never against the
   live, running system it will eventually become. That gap is real regardless of whether
   redeploy is immediate or manual.
2. **Rollback/commit-granularity risk — RETIRED.** This hazard previously read: "a multi-task
   batch commit mixes N tasks' index rows and diffs into one commit. If the self-modifying task's
   change needs to be reverted, isolating it from sibling tasks' unrelated changes in the same
   commit is harder than it would be for a solo, single-task commit." That batch commit no longer
   exists: MT mode now issues one scoped commit per task per phase transition, inside
   `skill-orchestrate`'s own per-task postflight loop (Stage MT-4 step 5.5), at the same
   granularity a solo run produces — see `docs/architecture/orchestrate-state-machine.md`'s
   "Commit Granularity" subsection. A self-modifying task's change is therefore isolated in its
   own commit, never mixed with a sibling task's diff. **Stated residual, not total elimination**:
   each per-task commit still stages `specs/state.json` and `specs/TODO.md`, which legitimately
   carry other tasks' current index rows (they are shared, wholesale-regenerated index files);
   `--honest-index-rows` labels this in the commit message. This is a labeled, honest residual, not
   a defect, and it does not revive this hazard — reverting a self-modifying task's commit still
   isolates that task's own source-store diff from every sibling's.
3. **Bootstrapping risk** (live) — admission for the task rewriting the admission predicate (or any
   of the other eight files) is decided by the OLD, currently-deployed copy of that same machinery.
   A defect the new candidate is trying to fix cannot fix its own admission decision; only a solo
   run followed by a manual redeploy breaks that circularity.

A later maintainer must not read the disproven live-corruption hypothesis as license to relax or
remove this gate — hazards 1 and 3 above remain live and are, on their own, sufficient rationale
to keep it. Hazard 2 is retained here in retired form, not deleted, so a later reader can see what
changed and why.

### Scope Limitation and Residual Risk

This gate is `/orchestrate`-only. Plain multi-task `/implement N,M`, `/research N,M`, and `/plan
N,M` never call `orchestrate-batch-admit.sh` at all, so a self-modifying task run through one of
those commands is invisible to this gate. This is a known, accepted scope limitation, not a
silently-absorbed gap — a follow-up task would be required to extend equivalent protection to
those commands, should that ever be judged necessary.

The batch-commit staging gap previously noted here — that the retired end-of-batch commit did not
stage an implementation agent's self-reported `modified_files` per task — is now closed: the
per-task commit described under hazard 2's retirement above stages each task's own `modified_files`
via the same contract single-task `/implement` uses (`context/standards/git-staging-scope.md`'s
"Multi-Task Application" subsection).

### Note on Reachability Durability

The reachability conclusion for the three explicitly-excluded files (`command-gate-in.sh`,
`command-gate-out.sh`, `orchestrator-postflight.sh`) is a fact about the CURRENT MT dispatch
implementation, not a permanent property of those files. If MT dispatch is ever rerouted through
the Skill tool in a way that sources any of them, the reachability test flips for that file and
it should be re-evaluated for inclusion using the same two tests above — not grandfathered out
because it was excluded once.

## Admission-Time vs. Mid-Flight: A Knowability Test

The boundary between admission-control checks and mid-flight checks is a **knowability** test,
not a cost test: a problem belongs to admission control if and only if the fact needed to detect
it already exists on disk before any agent is invoked. It belongs to mid-flight detection if and
only if that fact does not exist until an agent has acted.

**Admission-time (fact already on disk before dispatch)**:

- File-scope collision — the `file_scope` arrays of both tasks are already recorded.
- Held lock — the lock's existence and holder are already recorded.
- Unmet predecessor — the dependency edge and the predecessor's terminal status are already
  recorded.
- Stale handoff — the handoff file's mtime is already on disk.

**Mid-flight (fact does not exist until an agent has acted)**:

- Premature completion claims — whether phase headings actually flipped to complete cannot be
  known until the dispatched agent has run and its output can be compared against its self-report.
- Churn — a trend across two or more cycles is only observable after those cycles have occurred.
- Drift — the same: an inspection of what actually changed, only meaningful after the change has
  happened.

Each admission-time example is disambiguated by naming the specific on-disk fact that makes it
knowable before dispatch; each mid-flight example is disambiguated by naming the fact that does
not exist until an agent has acted.

## Batch-Size Scaling: Scope of Deferral, Not Existence of the Check

Batch size changes the **scope of what gets deferred**, never the **existence** of a blocking
check. The runtime wave/cycle-split check and the lock-acquisition refusal both already implement
this correctly: on conflict, only the one lower-priority colliding task is deferred, not the
whole batch. The consequence is explicit: a batch of eight never pays more than one deferred task
for any single conflict, so the existence of a check is orthogonal to how large the batch is
allowed to grow.

## Rejected Approaches

**Relaxing a blocking check to advisory as batch size grows** (equivalently, indexing check
strictness to batch size) is rejected, not merely discouraged. The reasoning: this imports the
approval-fatigue / rubber-stamping failure mode — documented for *human* reviewers operating
under volume — into *machine* admission control, where it does not apply. A machine overlap check
does not become harder to run, or less necessary, as concurrency rises; if anything the opposite.
Batching and summarization are the right answer for the human-facing review of a batch's
consolidated outcome (see Divergence from External Practice below); they are the wrong answer for
whether two tasks may safely run concurrently, which is a deterministic, per-pair, machine-checked
question independent of batch size. This is named here explicitly so a later, less-grounded pass
cannot rediscover it and adopt it as a tunable.

## Defer-Not-Fail: The Standing Default

Deferral is the standing default response to every admission-time conflict, not just the two
already implemented (wave/cycle-split deferral of the lower-priority task, and lock-acquisition
refusal). It generalizes to the two scan-scope gaps this document also flags as non-negotiables
below: a collision with a non-terminal, currently-unlocked task outside the batch, and a declared
dependency whose target lies outside the batch. Both should be deferred, never hard-failed.

The rationale: admission conflicts are transient by construction — they clear once the colliding
or blocking task terminates — whereas this system's failed/blocked states require human
intervention to clear. Treating a transient scheduling conflict as a terminal failure is
disproportionate to the conflict.

## Non-Negotiables

These five hold at any batch size and are never relaxed for throughput:

1. **Never promote to completed on a bare self-reported implementation status.** An outcome check
   on actual plan/artifact marker state (the handoff schema's `plan_markers_verified` field or
   equivalent) must gate it. Self-report is supplementary evidence only, never sufficient evidence
   on its own.
2. **Never narrow file-footprint or lock overlap scanning to the current invocation's task set as
   the only scope.** The scan must also reach non-terminal, currently-unlocked tasks outside the
   batch. Correctness of concurrent-write detection does not become cheaper as concurrency
   increases — it becomes more necessary.
3. **Never silently drop a dependency edge because its target is out of batch.** At minimum, warn
   loudly and exclude the dependent task by default.
4. **Never let human-facing batch approval substitute for or gate machine admission decisions.**
   Which tasks may run concurrently is a deterministic, per-pair, machine-checked question,
   independent of whether or how a human later reviews the batch's outcome.
5. **Never treat the batch-size cap as a correctness control.** It bounds human cognitive load
   over the consolidated output, not the soundness of per-pair admission checks. Raising it is
   safe only if the human-facing review strategy scales with it — the two are orthogonal
   questions and must be reasoned about separately.

## Divergence from External Practice

Stated plainly rather than smoothed over: the external human-in-the-loop literature this system's
design was checked against assumes a human is available to escalate to, synchronously, during a
run. This system assumes the opposite by design — autonomous orchestration has zero synchronous
confirmation gates between lifecycle phases. Escalation, when it happens, is a capped automated
fork sequence, and human review happens only after the fact, via the consolidated batch output and
the commit trail. No synchronous batch-approval gate exists here at all, and this document must
not be read as implying one does.

## Open Design Fork

For an out-of-batch dependency (Non-Negotiable 3 above), whether the right response is to exclude
the dependent task from the batch, or to auto-expand the batch to include the predecessor, is
unresolved. Both options are defer-not-fail-compatible; they differ in blast radius, and an
auto-expanded batch would itself need its own admission checks applied before the expansion is
safe. This is flagged as open, not decided, here.

**Accompanying bounded-scope note**: any future widening of the overlap scan (to close the
scan-scope gap in Non-Negotiable 2) should follow the existing bounded-scan precedent — compare
against a bounded set such as non-terminal tasks, never an unbounded scan of every task directory
— or it reintroduces the very cost problem this document exists to keep in check.

## Related Documents

This document states principles only. The mechanisms are defined, exactly once each, elsewhere:

- **Overlap algorithm**: `file-footprint-overlap.md` — the directory-prefix overlap predicate and
  its pairwise-set application, used by all three admission layers above.
- **Lock protocol**: `task-lock.md` — the lockfile schema, acquire/heartbeat/release contract, and
  the cross-task `file_scope` overlap check performed at lock-acquisition time.
- **Wave/cycle dispatch**: `commands/orchestrate.md` (Dependency Graph Construction and
  Topological Wave Assignment steps, and their runtime wave-split check) and
  `skills/skill-orchestrate/SKILL.md` (the Lifecycle-Cycling Loop's runtime wave-split step, and
  the Phase-Aware Dispatch and Per-Task Postflight stage that maps a self-reported implementation
  status to a postflight update).
- **Handoff schema**: `docs/architecture/handoff-schema.md` — the `plan_markers_verified` field
  referenced under the Blocking vs. Advisory and Non-Negotiables sections above, and the token
  budget any future mid-flight signal must fit inside if it needs to reach the state-machine
  loop (see the schema's Context Flatness Constraint, restated in `skill-orchestrate/SKILL.md`'s
  MUST NOT section).
- **Creation-time overlap component**: `docs/reference/standards/multi-task-creation-standard.md`
  — the file-scope capture and overlap-detection component invoked at task-creation time.
- **Self-modification hazard data and schema**: `context/reference/orchestrator-critical-paths.json`
  — the single declaration of the nine-file critical-path list and its `scope_roots` expansion
  rule, consumed by `scripts/orchestrate-batch-admit.sh`; and
  `docs/architecture/batch-admit-schema.md` — the `self_modifying` / `defer_reason` verdict fields
  this fourth dimension adds to the admission predicate's output.
