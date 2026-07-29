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
holding a lock is invisible to layers 1-3 simultaneously. Closing that gap is a scan-scope
question, addressed under Non-Negotiables and the Open Design Fork below, not a new-check
question.

**A FIFTH, bounded input — the session registry — narrows this gap further, without eliminating
it.** Both layer 3 (`task-lock.sh`'s `cmd_acquire`) and the layer-2 cross-batch extension
(`orchestrate-batch-admit.sh`) now additionally consult `specs/.sessions/*.json` — a live
registered session's own precomputed, UNIONED `file_scope` across every task it covers (see
`file-footprint-overlap.md`'s "Three Contention Inputs" section for the full asymmetry between
this input and the other two). This closes a specific sub-case the state.json collision scan
alone could not: a session ACTIVELY WORKING a task whose declared `file_scope` alone would not
overlap the candidate, but whose session-wide UNIONED footprint (spanning several covered tasks
at once) does. **What remains genuinely invisible, by design, is narrower than before, and
precisely stated rather than left implicit: a task with no held lock, no live session currently
covering it, AND — the residual case worth naming explicitly — a TERMINAL status.** A terminal
task is excluded from ALL three inputs' scans on purpose (a completed/abandoned/expanded task
will not write anything and must never block dispatch), so this is an intentional non-goal, not
an accidental gap. A genuinely idle, NON-terminal task with no lock and no live session is NOT in
this residual set — its declared `file_scope` remains visible to `orchestrate-batch-admit.sh`'s
pre-existing `specs/state.json` collision scan regardless of lock or session state, exactly as it
was before the session-registry input was added. Do not read the session-registry addition as
having closed MORE than this: it adds one more live signal alongside held locks and
`state.json`, it does not change what `state.json` itself already made visible.

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

### Inclusion Table (ten files, with per-file evidence)

Re-applied at the narrowing that added row 10 below: rows 1-9 were re-confirmed against both
conjunctive tests and are UNCHANGED — no row's reachability or decision-relevance verdict
differs from the prior evaluation.

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
| 10 | `scripts/verify-deploy.sh` | Executed directly from Stage MT-3 step 7 on the MT dispatch path (the inter-cycle redeploy checkpoint) | A defect causing a false PASS is silent and lets a broken deploy be treated as verified — matching row 7's own "a bug in it defeats the very check meant to catch bugs like it" language |

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
| `scripts/deploy-headless.sh` | Executed from Stage MT-3 step 7 immediately before `verify-deploy.sh`, so it is reachable on the MT dispatch path, but its primary failure mode is loud (`exit 1`/`2`, triggering the documented failure-path warning and `deferred_deploy_checkpoint` population) — matching the exclusion rationale already used for `validate-artifact.sh` above. Judged call, not an unconsidered omission: a hypothetical silent partial-sync defect (some files copied, some not, exit 0 anyway) would clear decision-relevance and belong in the Inclusion Table instead; the current implementation's failure mode is the loud one, so it stays here. |

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
3. **Bootstrapping risk — PARTIALLY RETIRED, replaced by a narrower mid-invocation script-swap
   exposure.** This hazard previously read: admission for the task rewriting the admission
   predicate (or any of the other eight files) is decided by the OLD, currently-deployed copy of
   that same machinery. A defect the new candidate is trying to fix cannot fix its own admission
   decision; only a solo run followed by a manual redeploy breaks that circularity. That framing
   is now split into three parts:
   - (i) **Structurally impossible, on a premise that has since changed**: the in-batch,
     correctly-declared form — a candidate whose declared `file_scope` names a critical path,
     admitted alongside a `dependencies[]`-edge-connected sibling in the same invocation — remains
     structurally impossible, but the REASON changed. It previously read on the self-modification
     admission gate excluding such a candidate from the **whole invocation** (the old, never-reset
     `deferred_self_modifying` exclusion set); that premise no longer holds — see "### The
     Same-Cycle Narrowing and Its Hazard Accounting" above. The claim survives on a narrower,
     already-sufficient premise instead: Stage MT-3 step 3's eligibility rule guarantees an
     edge-connected successor is never eligible in the same cycle as its predecessor, regardless of
     the self-modification gate's own scope. "W0 fixes it, W1 still runs stale" still cannot happen
     for a correctly-declared, edge-connected candidate — it just was never actually the
     self-modification gate's whole-invocation scope doing that work.
   - (ii) **The two residual forms the inter-cycle redeploy checkpoint retires**: **declared/actual
     divergence** — a task whose declared `file_scope` does not name a critical path but whose
     actual `modified_files` do, invisible to a gate that only reads `file_scope` pre-dispatch —
     and **cross-invocation staleness** — a correctly-excluded task is later re-run solo, commits
     its fix, and nothing redeploys it before the next invocation picks up stale machinery.
   - (iii) **The replacement exposure, named as such**: seven of the ten critical paths
     (`scripts/skill-base.sh`, `scripts/task-lock.sh`, `scripts/update-task-status.sh`,
     `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-triage-classify.sh`,
     `scripts/orchestrate-dry-run-report.sh`, `scripts/verify-deploy.sh`) are shell scripts
     re-invoked via a fresh `bash .claude/scripts/X.sh` subprocess at every use site, so they
     genuinely re-read on-disk bytes; the remaining three (`skills/skill-orchestrate/SKILL.md`,
     `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`) are read once into the
     orchestrator's context at dispatch time and are unaffected for the current turn. A mid-run
     redeploy therefore genuinely swaps executing machinery mid-flight for the seven script paths.
     This is the **same underlying verification-gap tension as hazard 1, now manifesting
     mid-session rather than only cross-session** — not an independent fourth hazard. See
     `### The Inter-Cycle Redeploy Checkpoint` below for the mechanism that retires (ii) and
     contains (iii).

A later maintainer must not read the disproven live-corruption hypothesis as license to relax or
remove this gate — hazard 1 remains fully live and hazard 3 remains partially live (its
replacement exposure, per (iii) above); together they are, on their own, sufficient rationale to
keep it. Hazard 2 is retained here in retired form, not deleted, so a later reader can see what
changed and why; hazard 3 is now retained in the same style, split into its retired and surviving
parts rather than being deleted either.

### The Same-Cycle Narrowing and Its Hazard Accounting

The self-modification defer originally excluded a candidate from the WHOLE invocation whenever
`--invocation-count` exceeded 1 — never merely from the wave/cycle it was actually co-dispatched
in. That whole-invocation scope has been narrowed to the candidate's actual same-cycle co-dispatch
count (`${#eligible_tasks[@]}` at the skill's own call site), because a
`dependencies[]`-edge-connected pair can never share that count in the first place — Stage MT-3
step 3's eligibility rule guarantees a successor is never eligible until its predecessor leaves
the non-terminal set — so the whole-invocation count fired against pairs that could never
actually co-occur in a dispatch batch. That was a pure false positive, not a safety margin, and
removing it removes no protection against any of the three hazards above.

**Which hazard each unit of remaining strictness pays for, stated per hazard**:

- **Hazard 2 (rollback/commit-granularity) — RETIRED, and whole-invocation scope was never this
  hazard's mitigation anyway.** Once MT mode moved to one scoped commit per task per phase
  transition (Stage MT-4 step 5.5), the commit-granularity concern the original whole-invocation
  scope might have incidentally helped with was already resolved by a DIFFERENT mechanism. The
  narrowing does not touch this hazard's retired status either way.
- **Hazard 3's in-batch form — RETIRED, and whole-invocation scope WAS this form's mitigation, now
  replaced.** The old whole-invocation exclusion is exactly what made "a self-modifying candidate
  admitted alongside a sibling in the same invocation" structurally impossible. The narrowing
  removes that specific protection — but does not reopen the hazard, because same-cycle
  eligibility exclusion (Stage MT-3 step 3) already makes the in-batch, correctly-declared form
  structurally impossible on its own: an edge-connected successor is never eligible in the same
  cycle as its predecessor, narrowed scope or not. The over-protection here was scope wider than
  the eligibility rule already required, not a hazard the wider scope alone was holding back.
- **Hazard 1 (verification gap) — LIVE, and UNAFFECTED BY THE SCOPE CHOICE IN EITHER DIRECTION.**
  A fix to orchestrator machinery is verified only against a scratch deploy-tree copy regardless
  of whether the defer is scoped to the whole invocation or to one cycle — the gap is about
  WHERE verification happens, not how widely a defer excludes a candidate. This is precisely why
  hazard 1 is not itself an argument for whole-invocation scope: it does not distinguish the two
  scope choices. It IS the reason some gate must survive at some scope, which is why this task
  narrows the defer rather than removing it.

**A1 resolution — the dependency-edge exemption asymmetry is explained, not remedied.** The
collision dimension (`file_scope_collision`) excludes from its comparison set any task connected
to the candidate by a `dependencies[]` edge in either direction. The self-modification dimension
applies no equivalent exemption, and this is deliberate, not an oversight: the collision
dimension's comparison set spans EVERY non-terminal task in `specs/state.json` — including tasks
far outside the current wave/cycle — where an edge-connected pair genuinely can and does collide
if left unexempted (an out-of-batch predecessor sitting in `implementing` for many cycles is a
real, live comparison target). The self-modification dimension's comparison, by contrast, is now
scoped to `${#eligible_tasks[@]}` — the current cycle's actual co-dispatch set — and Stage MT-3
step 3's eligibility rule already guarantees an edge-connected pair can never occupy that set
together. An explicit dependency-edge exemption in the self-mod branch would therefore be
unreachable dead code: the condition it would guard against cannot occur once the count is
same-cycle-scoped. The asymmetry between the two dimensions is real, but it is load-bearing only
on the collision side, where the wider comparison set makes the edge case reachable; it is not a
gap in the self-modification check.

**The `--allow-self-modifying` override — recorded, default off.** Name:
`--allow-self-modifying`. Default: off (`"false"`), threaded through
`scripts/parse-command-args.sh`'s scan and strip chain exactly like every other boolean flag, and
read at the consumer (`skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 and the
`skill-orchestrate-hard` transcription) — never passed to `orchestrate-batch-admit.sh`, which
always computes and emits the verdict honestly regardless of the flag. Justification for the
default: the narrowing itself trades a HUMAN-PACED solo re-run (where a person decides when to
redeploy after a self-modifying fix) for a self-modifying candidate now potentially running
inside ONE automated invocation, where the inter-cycle redeploy checkpoint auto-redeploys and
auto-verifies with ZERO human review in between. That is precisely the kind of automation hazard
1 warns is uniquely risky for an unverified orchestrator-machinery fix — a fix verified only
against a scratch deploy-tree copy, now also auto-deployed without a human looking at it first.
The override flag is framed as a deliberate, per-invocation, human-intent escape hatch for the
residual co-dispatch case (a genuinely co-dispatched self-modifying candidate that a human has
decided, this one time, should run anyway) — never as a general-purpose weakening of the gate.

### Scope Limitation and Residual Risk

**Corrected (this passage was stale)**: plain multi-task `/implement N,M`, `/research N,M`, and
`/plan N,M` are NOT blind to `orchestrate-batch-admit.sh` — each already runs a Batch Admission
Pre-Check (Step 2.5, "Gap C") that calls it over the whole validated candidate set with
`--invocation-count "${#validated_tasks[@]}"`, so a self-modifying candidate co-dispatched
alongside another candidate in the same plain multi-task batch IS deferred by this gate, exactly
as an `/orchestrate` co-dispatch is. What remains genuinely `/orchestrate`-only is the
**same-cycle narrowing** described above, not gate visibility itself — see the next paragraph.

**Decision, restated after the same-cycle narrowing: restate the acceptance, do not extend
protection.** The narrowing this document records above does NOT transfer to plain multi-task
`/implement`, `/research`, or `/plan` by analogy, and the reason is specific to what those
commands lack, not a general judgment that they are lower-risk. The narrowed self-modification
trigger is counted against `${#eligible_tasks[@]}` — a per-CYCLE co-dispatch set produced by
`/orchestrate`'s own Kahn-ordered wave/cycle machinery (Stage MT-3 steps 1-4). Plain multi-task
`/implement N,M`, `/research N,M`, and `/plan N,M` have no wave or cycle computation at all: no
Kahn ordering, no per-cycle eligibility re-evaluation, no concept of "this cycle's co-dispatch
set" for a narrowed trigger to be counted against. There is therefore no unit the narrowing could
even be expressed in for those commands — extending equivalent protection would require first
introducing a wave/cycle concept those commands do not have, which is a materially larger change
than narrowing an existing trigger. A future reader must not assume the narrowing implicitly
covered plain multi-task commands merely because it narrowed the analogous check inside
`/orchestrate`; a follow-up task would be required to extend equivalent protection to those
commands, should that ever be judged necessary. **This conclusion is specific to the
self-modification-hazard trigger and is unaffected by the file_scope-collision two-pass structure
described immediately below** — the two are orthogonal admission dimensions (see "The Three
Existing Admission Layers" above), and closing one's plain-multi-task gap has no bearing on the
other's.

**The `file_scope_collision` `in_batch` case, by contrast, NOW has a bounded plain-multi-task
analogue.** `commands/research.md`'s, `commands/plan.md`'s, and `commands/implement.md`'s Step
2.5 splits `defer_reason == "file_scope_collision"` by `collision_scope`: an `in_batch` hit is
re-sequenced into a new Step 3.5 (Second Pass) that re-runs `orchestrate-batch-admit.sh` over
exactly the deferred singleton/subset, rather than being dropped straight to `skipped_tasks` the
way it always was before. This is bounded at EXACTLY ONE extra pass — never a wave/cycle loop,
never more than the one bonus attempt `/orchestrate`'s multi-cycle machinery can make across many
cycles — and a task still deferred after that one extra pass lands in `skipped_tasks` with the
`"deferred after second pass"` reason, reporting the invocation's overall status as `partial`
rather than a hard failure. See `context/patterns/task-lock.md`'s "Four-Tier Conflict Response"
section (Tier 1) for the full mechanism and `context/patterns/multi-task-operations.md`'s
two-pass specification for the exact structural bound. Every other `file_scope_collision`
flavor (`cross_batch`) and every other defer flavor (`self_modifying`, `session_active`) keeps
the pre-existing single-pass exclude-to-`skipped_tasks` behavior verbatim — only the `in_batch`
file-scope case gained resequencing, and only within the current invocation's own candidate set,
never expanded to pull in an out-of-batch predecessor.

The batch-commit staging gap previously noted here — that the retired end-of-batch commit did not
stage an implementation agent's self-reported `modified_files` per task — is now closed: the
per-task commit described under hazard 2's retirement above stages each task's own `modified_files`
via the same contract single-task `/implement` uses (`context/standards/git-staging-scope.md`'s
"Multi-Task Application" subsection).

### The Inter-Cycle Redeploy Checkpoint

This subsection is the single, authoritative statement of the inter-cycle redeploy checkpoint
contract. Every other file that mentions the checkpoint (`regeneration-is-manual-only.md`,
`skills/skill-orchestrate/SKILL.md`, `commands/orchestrate.md`, `scripts/deploy-headless.sh`,
`scripts/verify-deploy.sh`) cross-references this subsection by path rather than restating it.

**Trigger**: the union of every task dispatched this cycle's actual `modified_files`, compared
against the `scope_roots x critical_paths` expansion of
`context/reference/orchestrator-critical-paths.json` using the directory-prefix overlap predicate
in `context/patterns/file-footprint-overlap.md` (both referenced by path, never restated here).
Non-empty overlap fires the checkpoint.

**Why `modified_files` and not `file_scope`**: the admission gate already performs the
`file_scope` check pre-dispatch (see the Self-Modification Hazard section above); using
post-dispatch `modified_files` is strictly more precise and closes the declared/actual divergence
gap named under hazard 3 above. The cost is a single jq comparison, since the array is already in
scope at Stage MT-4 step 5.5 of `skill-orchestrate/SKILL.md`.

**Rejected alternatives, recorded so a later pass cannot rediscover them**:
- **"Always redeploy between cycles"** — rejected. It imposes an unjustified deploy/verify cost
  on every cycle of every batch regardless of relevance, and it maximizes the script-swap window
  named in (iii) above rather than minimizing it.
- **A bare user-supplied opt-in flag** — rejected. It defeats `/orchestrate`'s zero-synchronous-
  confirmation-gates design (see Divergence from External Practice above): the operator cannot
  know in advance which cycle will touch a critical path, so an opt-in flag either fires on every
  invocation (equivalent to the first rejected alternative) or is never set when it matters.

**Failure contract**: on failure of either gate (`deploy-headless.sh` or `verify-deploy.sh`),
defer all remaining not-yet-dispatched tasks for the rest of the invocation. Never abort, never
silently continue. This is governed by the `## Defer-Not-Fail: The Standing Default` section
above. Abort is rejected because it discards `mt_state_file` bookkeeping for no benefit, since
deferral already halts further exposure. Silent-continue is rejected outright because the
operator would see nothing distinguishing "we didn't check" from "we checked, it's broken, and we
proceeded anyway" — the same reasoning the Blocking vs. Advisory criterion above applies to any
guardrail whose harm is silent and hard to detect after the fact.

**Sequencing**: per-task commits at Stage MT-4 step 5.5 already precede any point the checkpoint
can occupy, unconditionally and inside the same per-task loop iteration. Committed-then-redeployed,
in that order, is guaranteed by existing step ordering and is stated here, not built.

**Idempotence guard**: the checkpoint fires only when this cycle's overlap set contains at least
one critical path not already recorded in `mt_state_file.deployed_critical_paths`. Without it, a
task sitting in `implementing` across several cycles would re-report the same `modified_files`
and re-fire the checkpoint every cycle, at unbounded redundant deploy/verify cost and with the
mid-run script-swap window maximized rather than minimized. (`deployed_critical_paths` is its own
accumulating set, distinct from — and unaffected by — the same-cycle narrowing of
`deferred_self_modifying` described above; the two are not the same convergence mechanism.)

**Concurrency**: the whole-tree overwrite is serialized by a fail-open `specs/.deploy-lock/`
mutex inside `scripts/deploy-headless.sh`, the same acquire/warn-and-proceed shape as the
existing `specs/.commit-lock/` mutex in `scripts/git-commit-scoped.sh`.

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

**Auto-degrading a zero-dispatch batch into N sequential solo invocations** (Scope D) is rejected
in favor of PRINT-ONLY. Three-part justification:

(a) Each solo run pays its own full research/plan/implement dispatch cost. Silently converting one
zero-dispatch batch invocation into N solo invocations multiplies that cost without the caller's
consent.

(b) This system has zero synchronous confirmation gates by design (see Divergence from External
Practice below) — there is no point mid-run to obtain that consent. The absence of a confirmation
gate is a reason to take the SMALLER action (print the sequence) here, not licence to take the
bigger one (auto-execute it).

(c) Auto-degrading inverts defer-not-fail's own proportionality logic. Defer-not-fail exists to
make the system's response to a transient scheduling conflict SMALLER than the conflict — a
deferred task, not a failed one. Auto-executing N solo runs in response to a batch where nothing
was admitted is a larger response than the conflict warrants, the opposite direction from what
defer-not-fail is for.

The report therefore prints the dependency-ordered solo re-run sequence; the human runs it.

**Converting `commands/orchestrate.md`'s Kahn's-algorithm pseudocode into an executable script**
is rejected (recorded alongside the file_scope_collision two-pass work above, since both were
weighed together while adding plain multi-task resequencing). Cost of converting: the pseudocode
block's own comments explicitly warn against treating it as literal, executable logic, and
`commands/orchestrate.md` sits on the orchestrator-critical inclusion list (see
`context/reference/orchestrator-critical-paths.json`) — turning the illustration into a real
script would itself trip the self-modification hazard gate documented above for zero behavioral
gain, since `skill-orchestrate/SKILL.md` Stage MT-3 step 4.5 already auto-sequences the
`in_batch` case correctly without any such script. Cost of NOT converting: wave assignment stays
agent-executed pseudocode with no script-level test surface of its own — a future correctness bug
in wave assignment is caught only by the SKILL.md-level behavioral tests, not by a dedicated unit
test.

**Adding `file_scope` overlap as a pre-computed `in_degree`/wave-assignment input** (rather than
a purely reactive, dispatch-time defer) is likewise rejected. Cost of adding: it duplicates, in a
pre-computed graph, a decision the executing gate (`orchestrate-batch-admit.sh` /
`task-lock.sh`'s cross-task scan) already re-derives fresh at admission/acquire time every
cycle — creating two independent sources of truth for the same fact that can drift out of sync
with each other (the pre-computed graph could go stale between when it was built and when a
later cycle's live state has since changed). Cost of NOT adding: overlap remains a reactive,
dispatch-time defer rather than a pre-dispatch ordering signal, so a colliding pair is only
discovered at the moment dispatch is attempted, not earlier during wave planning. Both costs are
accepted; the duplication risk of the "adding" cost was judged worse than the reactive-only
discovery timing of the "not adding" cost.

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

### The Forward-Progress Invariant

A zero-dispatch batch — every validated candidate deferred, nothing admitted on any wave or
cycle of the invocation — is a consequence of defer-not-fail applied repeatedly across an entire
run, which is why this subsection follows that section rather than standing alone. Defer-not-fail
says any single conflict is deferred, never failed; it says nothing about what the invocation as a
whole must do when *every* candidate hits some conflict. This subsection names that whole-run
outcome and requires it to be legible, not merely correct.

**Canonical vocabulary, used verbatim at every site that renders or detects this outcome**:

- **Invariant name**: the **forward-progress invariant**.
- **Violation outcome name**: the **zero-dispatch outcome**.
- **Structured field name**: `forward_progress_violated` (boolean).
- **Observation ledger field name**: `defer_ledger`.
- **Human-facing banner**:
  `[ZERO DISPATCH - 0 of N validated candidates dispatched; forward-progress invariant violated]`.
- **Machine-readable marker**: `<!-- forward-progress violated=true dispatched=0 validated=N -->`.

**Statement, precise and cause-agnostic**: the invariant is violated when the validated-candidate
set is non-empty AND no task was dispatched on any cycle of the invocation. The operational test is
`mt_state_file.dispatch_start_ts == {}` at loop exit — that map is already written only at actual
dispatch (three call sites in the skill's Stage MT-4), so detecting the invariant requires no new
dispatch-side bookkeeping. This is true regardless of which defer reason produced it —
`self_modifying`, `file_scope_collision` (`in_batch` or `cross_batch`), or a redeploy-checkpoint
deferral all count identically.

**Detection/rendering split, three loci, named explicitly**:

1. **Detection** — computed once, at the skill's Stage MT-5, as the single source of truth over
   `mt_state_file`.
2. **Rendering (live path)** — the command's Step 5, the human-facing consolidated-output surface.
3. **Rendering (preview path)** — the `--dry-run` reporter, which renders the same vocabulary
   against its own static, single-pass admission analysis.

**Relationship to the existing convergence guard**: the `consecutive_no_dispatch_cycles` guard
prevents ONE specific non-convergence mode — a mutually-colliding self-modifying set spinning to
the cycle cap. The forward-progress invariant is the GENERAL outcome-legibility requirement
covering every cause, including `file_scope_collision` (both scopes) and out-of-batch unmet
predecessors, not only the self-modifying case the guard watches. This is a legibility requirement
layered on top of the guard, not a widening of it: the guard's trigger condition is unchanged, and
the invariant is detected independently, at loop exit, regardless of whether the guard ever fired.

**Empirical finding**: the predecessor narrowing of the self-modification defer (recorded above
under "The Same-Cycle Narrowing and Its Hazard Accounting") did not shrink this requirement. The
remaining zero-dispatch cases are demonstrated true positives of a correctly-working gate, not
artifacts of an over-broad prior rule — the mechanism class is several independent
self-modifying candidates sharing one cycle with no dependency edge to serialize them, which the
same-cycle narrowing neither creates nor removes.

**Exit/status contract (Scope C), confirmed, not changed**: a zero-dispatch invocation does not
mutate `specs/state.json`, does not add any task to `failed_tasks`, and does not mark any task
failed or blocked. This is the standing defer-not-fail default applied to the whole-run outcome,
unchanged by naming it. A no-dispatch cycle DOES still consume a cycle — `cycle_count` increments
unconditionally at Stage MT-3 step 6, after dispatch — and that too is unchanged.

**PRINT-ONLY, not auto-degrade (Scope D)** — see the new `## Rejected Approaches` entry below for
the full justification; this subsection states only the vocabulary, that section states the
reasoning.

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
   loudly and exclude the dependent task by default. **Status: the warn-loudly and
   distinguish-subcases clauses are now satisfied; the exclude-by-default clause remains as
   documented in the Open Design Fork below.** `scripts/orchestrate-predispatch-review.sh` runs
   before `commands/orchestrate.md` Step 2 discards out-of-batch edges to build its
   intra-batch-only Kahn graph, and classifies every raw `dependencies[]` entry on every
   candidate into one of four buckets — `intra_batch` (no finding), `out_of_batch_live`,
   `out_of_batch_terminal`, and `nonexistent` — warning loudly by task number and target for all
   three non-`intra_batch` subcases, including the terminal one (this Non-Negotiable draws no
   exception for a terminal target). This is a REVIEW stage only: it never excludes on its own
   account. It does not newly exclude an `out_of_batch_live` or `nonexistent` predecessor from
   live dispatch either — `dependency_graph` (built by `commands/orchestrate.md` Steps 2-3) is
   intra-batch-only, so an out-of-batch edge is simply absent from it, and
   `skills/skill-orchestrate/SKILL.md` Stage MT-3's eligibility check sees no predecessor to
   wait on. Closing that residual live-path exclusion gap is exactly the Open Design Fork
   question below, left unresolved by this warn-only stage on purpose.
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

## Open Design Fork — RESOLVED

For an out-of-batch dependency (Non-Negotiable 3 above), whether the right response is to exclude
the dependent task from the batch, or to auto-expand the batch to include the predecessor, was
previously left unresolved here. **Resolution: exclude the dependent task by default; never
auto-expand the batch.** Both options were defer-not-fail-compatible; they differ in blast radius,
and this is why exclude wins:

- **Precedent**: two structurally identical situations elsewhere in this codebase already chose
  exclude-and-warn over auto-expansion — `orchestrate-dry-run-report.sh`'s Step 6 ("Out-of-batch
  unmet predecessors") and `orchestrate-batch-admit.sh`'s `collision_scope == "cross_batch"`
  handling. A third, newly-diverging answer for the same shape of problem would be an
  unjustified inconsistency, not a considered design choice.
- **Blast radius**: auto-expanding the batch to pull in an out-of-batch predecessor would require
  that predecessor to pass the FULL admission check (self-modification, file_scope collision,
  lock contention, its own predecessors) before the expansion is safe to dispatch alongside —
  strictly more machinery layered onto a path that has had far less production exposure than the
  existing exclude-and-warn precedent.

This resolution is a recorded design decision, not (yet) a live-path behavior change: it applies
directly to `orchestrate-dry-run-report.sh`'s existing Step 6 exclusion (unchanged by this
decision) and gives future work a settled answer for closing the live-path gap described under
Non-Negotiable 3 above — `scripts/orchestrate-predispatch-review.sh` deliberately stays a
report-only REVIEW stage and does not itself implement this exclusion on the live dispatch path
(see that script's own header for the "never a fifth admission gate" framing). The fork is marked
resolved here so the reasoning survives for whichever future change implements the live-path
exclusion; the fork's text is not deleted.

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
  — the single declaration of the ten-file critical-path list and its `scope_roots` expansion
  rule, consumed by `scripts/orchestrate-batch-admit.sh`; and
  `docs/architecture/batch-admit-schema.md` — the `self_modifying` / `defer_reason` verdict fields
  this fourth dimension adds to the admission predicate's output.
- **Deliberate-invocation constraint and its automated exception**:
  `context/patterns/regeneration-is-manual-only.md` — the "must be invoked explicitly" constraint
  this document's inter-cycle redeploy checkpoint is the one recorded, additive carve-out against
  (see that file's `## Automated Exception` subsection).
