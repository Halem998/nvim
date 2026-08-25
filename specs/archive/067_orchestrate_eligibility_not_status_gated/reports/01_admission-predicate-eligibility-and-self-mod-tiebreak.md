# Research Report: Task #67

**Task**: 67 - Make /orchestrate admission gates ordering constraints, not exclusions: unstrand in-flight tasks and end solo-only self-modifying dispatch
**Started**: 2026-08-17
**Completed**: 2026-08-17
**Effort**: large (two coupled work streams, ~12-file co-maintenance set)
**Dependencies**: None
**Sources/Inputs**:
- Live re-measurement: `specs/state.json`, deployed `task-lock.sh check` against tasks 22/28/31
- Codebase: `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
  `orchestrate-triage-classify.sh`, `reconcile-task-status.sh`, `task-lock.sh`,
  `command-gate-in.sh`, `parse-command-args.sh`, `scripts/lib/file-scope-overlap.sh`
- Codebase: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `skills/skill-orchestrate-hard/SKILL.md`, `commands/orchestrate.md`
- Codebase: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/system-defect-discrimination.md`,
  `context/reference/orchestrator-critical-paths.json`
- Codebase: `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`,
  `docs/architecture/batch-admit-schema.md`
- Codebase: `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Live evidence corrected and reconfirmed.** Tasks 22 and 31 (both `researching`) and 28
  (`implementing`) all hold `.lock/` directories from dead session `sess_1786459614_0c9ada`,
  now measured at `heartbeat_age_min≈9156-9169` against `threshold_min=30` — `held-stale`, exit
  2, via `.claude/scripts/task-lock.sh check`. Only 22 and 31 are actually excluded by the
  eligibility defect (`implementing` was never in the exclusion set). Both 22 and 31 have **no
  artifacts at all** (`reports/` empty), so `reconcile-task-status.sh` genuinely no-ops on them
  today — its "no artifact, genuine in-progress" branch is not itself a bug for this case.
- **A large fraction of the "ordering constraint, not exclusion" philosophy has already shipped**,
  in a prior convergence this task's own file_scope was drafted without full visibility into.
  `deferred_self_modifying` is already an *observation log*, not an exclusion set; a
  `consecutive_no_dispatch_cycles` convergence guard already bounds non-convergence at 3 cycles;
  `orchestrate-batch-admit.sh` is already schema v5 with an evidence-gated
  `idle_overlap_advisory` that already narrowed the `cross_batch` gate from blanket exclusion to
  admit-with-advisory for idle (non-executing) colliding tasks. **What remains unfixed, and is
  this task's real scope**, is exactly the two things named in the task title: Stage MT-3 step
  3's literal `{researching, planning}` eligibility exclusion (line 1456,
  `skills/skill-orchestrate/SKILL.md`), and `orchestrate-batch-admit.sh`'s self-modification
  branch (lines 476-495), which still has no tie-breaker and will deadlock for 2+ co-dispatched
  self-modifying candidates exactly as described.
- **New, load-bearing finding for the single-task engine**: `scripts/command-gate-in.sh` already
  calls `task-lock.sh acquire-retry` and aborts the *entire* single-task invocation if a fresh
  foreign lock refuses it, **before** `skill-orchestrate/SKILL.md` Stage 1 ever runs. By
  construction, Stage 4's `researching`/`planning` handlers (lines 359-367, 408-410) can only be
  reached after this session has *already* successfully acquired the task's own lock. Their
  message ("is currently being researched in another session") is therefore provably false in
  every reachable case today. This is strong grounds to **converge**, not diverge, the
  single-task engine.
- **The convergence-argument blast radius is narrower than the task description anticipated.**
  Grep confirms the "structurally impossible" safety claims cited across
  `orchestrate-batch-admit.sh`, `batch-orchestration-guardrails.md`, `commands/orchestrate.md`,
  and `batch-admit-schema.md` rest on the **dependency-terminal-state** clause of the eligibility
  rule (item 4: "all predecessors are in terminal state"), which Work Stream A does not touch —
  these survive unedited. Only the literal "`entering researching/planning`, terminating, or
  failing" convergence-exit-condition phrase — occurring at exactly **5 sites** — depends on the
  status-gate clause Work Stream A removes, and needs correction.
- **Recommended scope for Work Stream B**: adopt Direction 1 (deterministic designated-candidate
  tie-breaker, lowest task number wins) and Direction 2 (phase-aware gating — self-mod gate
  applies only to `implement`-phase dispatches). **Reject Direction 3** (redeploy-boundary
  serialization) outright, not merely defer it to a follow-up: re-derivation of the existing
  step-ordering contract shows the hazard it targets cannot occur under the current architecture
  — dispatch is cycle-synchronous and every task's commit lands before the redeploy checkpoint
  ever runs, so "siblings in flight across a redeploy" is not a real state today.
- **Scope is narrower than declared file_scope implies.** `scripts/parse-command-args.sh` and
  `context/reference/orchestrator-critical-paths.json` do not need edits for either recommended
  direction — no new flag, no per-path phase metadata is required. Recommend leaving both
  untouched, consistent with the task's own "if it turns out not to need editing, leave it
  untouched" instruction.

## Context & Scope

Two coupled defects in `/orchestrate`'s multi-task admission predicate, both required to land
together because Work Stream B's tie-breaker supplies the replacement convergence exit condition
that Work Stream A's status-gate removal displaces, and because splitting them into separate
self-modifying tasks would deadlock under the very defect being fixed. Full acceptance criteria,
live evidence, and directions-to-evaluate are given verbatim in the task description; this report
re-measures every claim against current source (all cited line numbers below are current,
freshly re-grepped — not carried from the originating report) and records a decision, with
reasoning, for every open question the task poses.

## Findings

### Re-measured live evidence

```
$ jq -r '.active_projects[] | select(.project_number==22 or .project_number==28 or .project_number==31)
         | {project_number, status}' specs/state.json
22 researching   28 implementing   31 researching

$ bash .claude/scripts/task-lock.sh check 22   # held-stale session=sess_1786459614_0c9ada heartbeat_age_min=9156 threshold_min=30, exit 2
$ bash .claude/scripts/task-lock.sh check 28   # held-stale session=sess_1786459614_0c9ada heartbeat_age_min=9169 threshold_min=30, exit 2
$ bash .claude/scripts/task-lock.sh check 31   # held-stale session=sess_1786459614_0c9ada heartbeat_age_min=9156 threshold_min=30, exit 2
```

`specs/022_.../reports/` and `specs/031_.../reports/` are both empty (no artifacts of any kind).
`specs/028_.../reports/` and `.../plans/` both hold artifacts (`01_mcp-ownership-rewrite-and-
purge-spec.md`, `01_mcp-ownership-hybrid-rewrite.md`); `.../summaries/` is empty. Only 22 and 31
are actually excluded by the eligibility defect — 28's `implementing` status was never in the
`{researching, planning}` exclusion set, so 28 is a stale-lock example, not an eligibility-defect
example; `task-lock.sh acquire`'s stale-override already resolves it whenever it is next
dispatched, with no eligibility change needed. Re-measure again immediately before implementation;
the stranded set is a moving target.

`scripts/task-lock.sh cmd_acquire` (read directly, lines ~616-745): refuses (exit 1, "ABORT") only
for a fresh (`age <= TASK_LOCK_STALE_MIN=30`) foreign lock; overrides-and-warns (exit 0, "WARN...
overriding") for a stale one; never reads `.status`. `cmd_check` (lines 905-931) returns exit 0
"free" (no lock dir), exit 1 "held-fresh", exit 2 "held-stale", exit 3 on a resolution error. This
fully confirms the task description's corrected premise: the lock layer is already the concurrency
arbiter and already behaves correctly for the stale-foreign-lock case.

### The self-modification gate has already been substantially narrowed — by a prior change

`skills/skill-orchestrate/SKILL.md` (Stage MT-1, lines 1251-1262) documents `mt_state_file
.deferred_self_modifying` as an "APPEND-ONLY OBSERVATION LOG... no longer an eligibility-exclusion
set." A `consecutive_no_dispatch_cycles` counter (Stage MT-3 step 4.5, lines 1651-1669) already
bounds the empty-dispatch-batch case at 3 cycles, exiting `partial` with the diagnostic:
"self-modification gate produced N consecutive cycles with zero dispatched tasks; likely a
mutually-colliding self-modifying set; re-run affected tasks solo or pass --allow-self-modifying"
(verbatim, still present at line ~1667-1669). `orchestrate-batch-admit.sh` is already at schema
`v5` and already ships `idle_overlap_advisory` (narrowing the `cross_batch`
`file_scope_collision` gate from blanket exclusion to admit-with-advisory whenever the colliding
out-of-batch task carries **no execution evidence**, i.e. status not in `{researching, planning,
implementing}` — see the script's own header, "Deferral-direction rule," and lines 526-541 of its
inline `jq`). `skill-orchestrate-hard/SKILL.md`'s Multi-Task Mode section (lines 1539-1638)
already transcribes this whole admission-gate mechanism in full, explicitly because a prior audit
found "a repo-wide grep for `batch-admit` against this file found ZERO references" — i.e. it was
already caught once for exactly the bare-pointer failure mode the task description worries about
for the eligibility rule.

**Consequence for scope**: the task description's five-gate table ("measured current state") is
stale relative to current source on one row. `cross_batch` `file_scope_collision` is **not**
currently a blanket exclusion — it already degrades to advisory-admit for idle colliding tasks,
and only remains a genuine per-invocation exclusion when the colliding out-of-batch task itself
carries live execution evidence. That residual case is structurally coupled to Work Stream A: once
A ends permanent researching/planning stranding, an out-of-batch task that currently blocks a
`cross_batch` collision forever (because it is *itself* stuck in `researching` under the status
bug) will instead actually progress and leave `{researching, planning, implementing}` in bounded
time. **Decision**: `cross_batch` and `deploy_checkpoint` are OUT OF SCOPE for this task (see
Decisions below) — not because they are unimportant, but because `cross_batch`'s residual
exclusion is a downstream symptom Work Stream A already repairs, and `deploy_checkpoint` is a
structurally different, deliberate infra-safety gate (see Decisions).

**What is genuinely still unfixed** (confirmed by direct read of `orchestrate-batch-admit.sh`
lines 476-495): the self-modification branch is still exactly
`if ($sm_flag == true) then if ($inv_count > 1) then defer else admit end`. Two or more
co-dispatched self-modifying candidates in the same invocation will all carry `sm_flag: true` and
all see `inv_count > 1` every cycle — none can ever become the sole candidate — so this literally
deadlocks until `consecutive_no_dispatch_cycles` trips at 3 and the invocation exits `partial`
with the still-present "re-run affected tasks solo" diagnostic. This is Consequence B, confirmed
live and unrepaired.

### Work Stream A: the actual unfixed rule, and its exact edit sites

`skills/skill-orchestrate/SKILL.md` Stage MT-3 step 3 (current text, line 1456): **"Status is NOT
`{researching, planning}` (in-flight from prior cycle)"** — this bullet is the OBSERVED DEFECT,
confirmed still present verbatim. `orchestrate-triage-classify.sh` (read in full) confirms
`researching`/`planning` are named nowhere in its `jq` classification chain; both fall into the
final `else` arm, `group: "skip"`, `reason: "...transitional/unknown"` (lines 298-301). Its own
header table (lines 55-65) documents this as `| researching, planning, unknown | skip | skip |`.
Single-task Stage 4's `researching` handler (lines 359-367) and `planning` handler (lines 408-410)
both hard-`EXIT (partial)` with a message asserting another session owns the task.

**New finding, not in the originating evidence**: `scripts/command-gate-in.sh` (lines 87-98) runs
`task-lock.sh acquire-retry` and `return 1`s (aborting the whole single-task `/orchestrate`
invocation) *before* `skill-orchestrate/SKILL.md`'s Stage 1 is ever entered, whenever a fresh
foreign lock refuses after the bounded retry budget. This means: by the time Stage 4's
`researching`/`planning` handlers can possibly execute, this session has *already* successfully
acquired the task's own lock (freshly, or via stale-override) — the "another session is actively
researching" framing is therefore always false at that point in the control flow, not merely
false in the specific measured cases. This is the strongest available argument for converging
(not diverging) the single-task engine's behavior with the multi-task fix, and it directly rebuts
the single-task engine's own stated rationale, since that rationale's premise (another live
session owns the lock) cannot hold at the point the code checks it.

**Comparison-set safety argument for Direction (a)** (why it is safe to stop excluding
`researching`/`planning` from `eligible_tasks`): once a task in `eligible_tasks` is classified and
dispatched, Stage MT-4's per-task `task-lock.sh acquire` (line 1902) is a *second*, independent
gate, run after admission and before dispatch. Per its own documented contract (lines 1912-1920):
"If `acquire` refuses (exit 1 — a fresh lock held by a genuinely different session; same-session
re-entry... never refuses), remove that task from this cycle's dispatch batch (do NOT add it to
`failed_tasks`...)". This is *already* a defer-not-exclude gate with exactly the right semantics —
a genuinely fresh foreign lock defers the task (ordering constraint), a stale one is silently
reclaimed. Removing the status-based *eligibility* exclusion therefore does not remove any actual
safety property: it removes a redundant, less accurate proxy (status string) for a real mutex
(the lock) that already runs downstream of admission and already degrades correctly.

### Convergence-argument re-derivation — narrower than assumed, five precise sites

The task description asks that "every one" of the load-bearing safety claims be re-derived. Direct
re-grep across the co-maintenance set shows two structurally distinct claim families that must be
told apart:

1. **Dependency-terminal-state claims** ("Stage MT-3 step 3's eligibility rule guarantees a
   successor/edge-connected pair is never eligible until its predecessor terminates/leaves the
   non-terminal set") — found at `orchestrate-batch-admit.sh` lines 189-198 (A1),
   `batch-orchestration-guardrails.md` lines 202, 240, 256-259, 277,
   `commands/orchestrate.md` lines 261-264, and `batch-admit-schema.md` lines 153-160. **All of
   these rest on eligibility item 4** ("all predecessors from `dependency_graph[task_num]` are in
   terminal state or `failed_tasks`"), which Work Stream A does **not** touch. **These sites need
   no edits.** This is a material correction to the task description's framing, which treated "the
   eligibility rule" as one undifferentiated claim; it is actually two independent clauses (item 3,
   status; item 4, dependency-terminal-state), and only item 3 is in scope here.

2. **Status-transition convergence-exit claims** (the literal "leaves `eligible_tasks` — entering
   `researching`/`planning`, terminating, or failing" phrase) — found at exactly these 5 sites,
   confirmed by grep:
   - `skills/skill-orchestrate/SKILL.md:1258` (Stage MT-1 field doc for `deferred_self_modifying`)
   - `skills/skill-orchestrate/SKILL.md:1561` (Stage MT-3 step 4.5, `in_batch` collision branch —
     explicitly flagged in-file as "load-bearing for the convergence argument elsewhere")
   - `skills/skill-orchestrate/SKILL.md:1658` (Stage MT-3 step 4.5, self-mod convergence-guard
     rationale)
   - `skills/skill-orchestrate-hard/SKILL.md:1585` (transcribed `in_batch` branch)
   - `docs/architecture/batch-admit-schema.md:288`
   **These 5 need editing.** Additionally, the eligibility-rule *restatement itself* (not the
   convergence-exit claim) appears independently at `skills/skill-orchestrate/SKILL.md:1456`
   (the rule itself), `docs/architecture/orchestrate-state-machine.md:335-336` (ASCII diagram) and
   `:379-382` (Dependency Gating Model prose) — these need the `{researching, planning}` exclusion
   bullet removed outright, and `skills/skill-orchestrate/SKILL.md:1877-1885` +
   `orchestrate-triage-classify.sh`'s header table (lines 55-65) + its `jq` chain (lines 293-301)
   need two new rows added (see below).

**Deeper re-derivation of what actually makes the convergence claim true**: tracing one cycle by
hand shows the "entering researching/planning" clause was already the *weakest, rarest*
contributor even before this fix. A sibling task's own dispatch (preflight→Agent call→postflight)
resolves within a single cycle under normal operation; by the next cycle's status refresh it is
back to a non-in-flight status (`researched`/`planned`/terminal), so it typically re-qualifies for
`eligible_tasks` in a *different* phase group rather than actually leaving the set. The clause
only ever manifested for the crash/stranding path — precisely the bug Work Stream A fixes — so
removing it from the exit-condition list is a correction, not a loss of a routine mechanism. The
two remaining clauses, "terminating" and "failing," are unaffected by Work Stream A and remain the
real, routine convergence mechanism (bounded by `MAX_CYCLES_MT = min(task_count*5, 25)`).
**Recommended replacement text** for all 5 sites: "...once its co-dispatched sibling leaves
`eligible_tasks` by terminating or failing (a task no longer leaves `eligible_tasks` merely by
entering `researching`/`planning` once eligibility is no longer status-gated)." For the two
self-modifying-specific sites (1258, 1658, and the hard-mode 1585 mirror), additionally note Work
Stream B's designated-candidate mechanism as a *second, independent, per-cycle* exit condition
that does not depend on any status transition at all — this is the mechanism that actually bounds
Consequence B, and is materially stronger than the status-transition argument ever was for the
two-or-more-self-modifying case.

### Work Stream B: recommended designated-candidate tie-breaker, and rejection of Direction 3

**Direction 1 (tie-breaker) — adopt.** Compute, within `orchestrate-batch-admit.sh`'s existing
single `jq` invocation (it already has `$cands`, the full candidate array, and the sourced
`self_mod_match` def from `scripts/lib/file-scope-overlap.sh` in scope — no change to that shared
library is required), the set of candidates in `$cands` for which `self_mod_match` matches, and
designate the **lowest task number** in that set as this cycle's admitted self-modifying
candidate. Change the branch from `if ($sm_flag == true) then if ($inv_count > 1) then defer else
admit` to `if ($sm_flag == true) then if ($inv_count > 1 and $c != $designated_sm_candidate) then
defer else admit`. Rationale for "lowest task number": it is the same ascending-`project_number`,
first-match determinism convention already used throughout this exact file (the `in_batch`
collision deferral direction, and the self-modification first-match rule itself) — no new
convention is introduced, and it needs no extra I/O (dependents-count would require walking
`dependencies[]` across all candidates for no clearly better guarantee).

**Scope note, stated precisely**: this predicate, read literally, also relaxes Consequence A —
a *lone* self-modifying candidate among ordinary siblings is trivially "the designated candidate"
(there is no other self-modifying candidate to lose to), so it now admits immediately rather than
waiting to be the sole eligible task. Re-derivation of the three surviving hazards in
`batch-orchestration-guardrails.md` ("Hazard 1: verification gap," "Hazard 2: RETIRED," "Hazard
3(i): RETIRED for edge-connected pairs") shows this is safe: hazard 1's actual claim is that the
fix is *verified only in a scratch deploy-tree copy* — true regardless of what else is
co-dispatched, and not mitigated by deferring co-dispatch, since redeploy (Stage MT-3 step 7)
already runs strictly *after* every this-cycle dispatch's own commit (line 1721: "every task
dispatched this cycle already had its own scoped commit attempted... unconditionally, before this
step runs"). No ordinary sibling's dispatch is ever concurrently exposed to an unredeployed,
unverified machinery change — the tree does not change mid-cycle regardless of what admits.
**Decision**: adopt the full Direction 1 as specified (not artificially restricted to the 2+
self-mod case), and record explicitly in the implementation that this also incidentally closes
Consequence A's 3-wasted-cycle case — this is a deliberate, reasoned, in-scope consequence, not
scope creep, and the plan should verify it via a dry-run fixture (1 self-mod + 2 ordinary tasks,
confirming the self-mod task no longer waits for the ordinary siblings to clear).

**Direction 2 (phase-aware gating) — adopt.** Ordering claim VERIFIED directly: Stage MT-3 step
4.5 (admission, calling `orchestrate-batch-admit.sh`) runs at line ~1489, strictly before Stage
MT-4's classifier call (`orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"`, line 1852).
Confirmed: admission today has no visibility into which phase (`research`/`plan`/`implement`)
each candidate would actually dispatch to this cycle. **Recommended mechanism**: call the
classifier once, earlier — inside Stage MT-3 step 4.5, immediately before building the admission
call — and thread its already-computed NDJSON group mapping forward into Stage MT-4 rather than
re-invoking the classifier a second time (the classifier is read-only and idempotent, but nothing
mutates `state.json` between step 4.5 and Stage MT-4 within one cycle, so reuse is both safe and
avoids a duplicate read). Pass the per-candidate phase to `orchestrate-batch-admit.sh` as a new
optional argument (e.g. `--phase-map task:group[,task:group...]`), parsed alongside the existing
`--invocation-count`/`--session-id` flags; when a phase map entry names `research` or `plan` for a
self-modifying candidate, do not apply the `self_modifying` defer branch regardless of
`inv_count` — `self_modifying` remains `true` on the verdict for visibility (per the script's
existing D5-style "hazard stays visible even when not deferred" convention), but `decision`
resolves to `admit`. **This requires no change to `scripts/lib/file-scope-overlap.sh`** — the
phase gate is a candidate-local decision made in `orchestrate-batch-admit.sh`'s own inline `jq`,
not part of the shared overlap-matching library.

**Direction 3 (redeploy-boundary serialization) — reject, not merely defer.** Re-derivation of
`batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint" and Stage MT-3 step 7's
"Sequencing guarantee" (skill-orchestrate/SKILL.md lines 1720-1723) shows the hazard Direction 3
targets — "the redeploy checkpoint rewriting the running orchestrator's own definition while
sibling dispatches are in flight" — cannot occur under the current architecture. Dispatch is
cycle-synchronous: all of a cycle's Agent calls are issued in one message and awaited to
completion (the BATCHING RULE / COMPLETION SEQUENCING contract), every dispatched task's own
scoped commit lands at Stage MT-4 step 5.5 inside that same cycle, and only then does Stage MT-3
step 7 evaluate the redeploy checkpoint. There is no cross-cycle concurrency in this design at
all — cycle N+1 cannot begin until cycle N's dispatch, postflight, and redeploy-checkpoint steps
have all completed. "Let everything dispatch, hold the redeploy until in-flight siblings reach a
cycle boundary" is therefore already exactly what happens today, by construction, not a new
mechanism to build. **Recommendation**: do not create a follow-up task for Direction 3 either —
record this finding in `batch-orchestration-guardrails.md`'s Inter-Cycle Redeploy Checkpoint
subsection as an explicit "considered and found already satisfied" note, so a future reader does
not rediscover and re-propose it.

### Classifier fixture gap, confirmed

`scripts/tests/test-orchestrate-triage-classify.sh` (read in full) covers only the `partial`
continuation-pointer predicate (fixtures A-D), plus one `not_started` sandbox probe for the
`single` engine only. **No fixture exists** for `researched`, `planned`/`implementing`, `blocked`
(either engine), terminal statuses, unknown/garbage statuses, or — the row this task changes —
`researching`/`planning`. New fixtures needed (both `single` and `mt` engines except where noted):
`not_started`→research (mt, to pair with the existing single-only probe), `researched`→plan,
`planned`/`implementing`→implement, `blocked`→needs_human (single) / skip (mt) — the one
documented engine-divergent row, an unrecognized status string→skip, a terminal status→terminal,
and the two new rows this task adds: `researching`→research and `planning`→plan (both engines) —
these two are the mutation-check fixtures: they MUST fail against the pre-fix classifier (which
currently emits `group: "skip"` for both) per `context/standards/shell-script-testing.md`'s
mutation-check discipline.

### Scope-narrowing findings for `parse-command-args.sh` and `orchestrator-critical-paths.json`

Both were added to file_scope defensively ("may need a flag," "may need per-path phase
metadata"). Neither recommended direction requires either:
- **`parse-command-args.sh`**: Direction 1's tie-breaker is fully automatic and deterministic — no
  operator choice is involved, so no new flag is needed. Direction 2's phase-awareness is likewise
  automatic (derived from the classifier, not from operator input). The existing
  `--allow-self-modifying` / `--allow-scope-collision` flags remain valid, unmodified escape
  hatches for any residual case a human wants to force. **Recommend: no edit.**
- **`orchestrator-critical-paths.json`**: phase-aware gating (Direction 2) is a property of *which
  phase a candidate is dispatching to this cycle*, not of *which specific critical path its
  file_scope matched* — no per-path phase metadata is needed; the same phase gate applies
  uniformly regardless of which entry matched. **Recommend: no edit**, unless implementation
  surfaces an actual need (e.g. a future critical path that is unsafe even during `plan`) — no
  such case exists in the current 14-entry registry.

Per the task's own SCOPE RULES ("If either turns out not to need editing, leave it untouched
rather than inventing a change"), the plan should not force edits to either file.

### Recorded, not acted on: `reconcile-task-status.sh` demotion (Direction b), scoped

Direction (a) (status-gate removal) is sufficient and necessary; Direction (b) is recommended as
**defense-in-depth**, scoped narrowly. `reconcile-task-status.sh`'s `researching`/`planning`
branches currently no-op when no artifact is found (confirmed live: this is exactly the branch
tasks 22/31 hit). Add an optional demotion check *only* reached after the existing no-artifact
no-op condition, gated on `task-lock.sh check "$task_number"` (confirmed exit contract: 0=free,
1=held-fresh, 2=held-stale, 3=resolution-error): demote `researching`→`not_started` or
`planning`→`researched` **only** when `check` returns exit 0 or exit 2 (never exit 1 — a
genuinely fresh lock must never be demoted; never exit 3 — fail closed on ambiguity, no
demotion). This both (i) gives operator-visible repair independent of the `/orchestrate`
eligibility fix — a plain `/research`/`/plan` re-invocation, or a future `/orchestrate` run, also
benefits — and (ii) is exactly what `context/patterns/system-defect-discrimination.md`'s
recorded-but-undecided follow-on (lines ~330-336: "Whether they belong in `critical_paths` for
the file's *other* consumer — the self-modification-hazard check... is a separate question... not
decided") anticipates as a live open question for `reconcile-task-status.sh`. Since this task adds
new logic to that file, it should also be added to `orchestrator-critical-paths.json`'s
`critical_paths` list (NOT the `recursion_guard` subset — that subset is scoped to the
discrimination/recording pipeline only, per that same document's explicit exclusion of
`reconcile-task-status.sh` from it) — this is a genuine, motivated addition, unlike the two "no
edit needed" files above.

## Decisions

1. **Work Stream A mechanism**: Direction (c) — both (a) and (b). (a) is the primary mechanism:
   remove the `{researching, planning}` exclusion from `skills/skill-orchestrate/SKILL.md` Stage
   MT-3 step 3 (line 1456); add `researching`→`research`, `planning`→`plan` rows to
   `orchestrate-triage-classify.sh`'s `jq` chain and header table; update Stage MT-4's phase
   grouping table; converge single-task Stage 4's `researching`/`planning` handlers to dispatch
   (mirroring `not_started`/`researched`) rather than `EXIT (partial)`, justified by the
   command-gate-in.sh finding above. (b) is defense-in-depth: add a lock-aware demotion guard to
   `reconcile-task-status.sh`'s `researching`/`planning` branches, gated strictly on
   `task-lock.sh check`'s exit code as specified above.
2. **Single-task engine**: converge (do not diverge). The command-gate-in.sh finding shows the
   current divergence's own stated premise cannot hold at the point it is checked.
3. **`blocked` and `unknown` rows**: leave unchanged, per the task's own default. No argument
   surfaced during this research to widen scope to either row.
4. **Convergence-argument edits**: exactly 5 sites need the "entering researching/planning"
   clause corrected (enumerated above); the dependency-terminal-state claims at
   `orchestrate-batch-admit.sh`, `batch-orchestration-guardrails.md` (4 sites),
   `commands/orchestrate.md`, and `batch-admit-schema.md` need **no edits** — they rest on a
   different, unaffected clause of the eligibility rule.
5. **Work Stream B directions**: adopt Direction 1 (designated-candidate tie-breaker, lowest task
   number, implemented entirely within `orchestrate-batch-admit.sh`'s existing `jq`) in full,
   including its Consequence-A-relaxing effect. Adopt Direction 2 (phase-aware gating via a new
   `--phase-map` argument, classifier call moved earlier in Stage MT-3 step 4.5). **Reject**
   Direction 3 outright — the hazard it targets does not exist under the current
   cycle-synchronous architecture; record this as a closed question in
   `batch-orchestration-guardrails.md`, not a follow-up task.
6. **General principle**: state it normatively in `batch-orchestration-guardrails.md` (a new
   short subsection cataloguing the (now four, post-fix) admission gates and their ordering-vs-
   exclusion status), but scope `cross_batch` and `deploy_checkpoint` OUT of this task — `
   cross_batch`'s residual exclusion is a downstream symptom this task's Work Stream A already
   addresses (an out-of-batch task that currently blocks forever will now itself progress);
   `deploy_checkpoint` is a deliberate infra-safety gate whose exclusion is not a defect (a failed
   `verify-deploy.sh`/`deploy-headless.sh` genuinely requires human remediation before any further
   redeploy-touching work should proceed).
7. **Convergence-guard diagnostic**: update the "re-run affected tasks solo" wording — it should
   no longer be the *likely* cause once the tie-breaker prevents the pure self-mod-vs-self-mod
   deadlock. Recommend reframing to name a tie-breaker bug, a `deploy_checkpoint` exclusion
   interacting with the batch, or an unexpected `file_scope_collision`/`session_active` chain as
   the more likely causes if this diagnostic ever fires again, while keeping `--allow-self-
   modifying` as a legitimate residual override, never removing the guard mechanism itself.
8. **`parse-command-args.sh` and `orchestrator-critical-paths.json`**: no edits needed for the
   adopted directions (see Scope-narrowing findings above). `orchestrator-critical-paths.json`
   *does* need one addition if Direction (b) is implemented: `reconcile-task-status.sh` should be
   added to `critical_paths` (not `recursion_guard`).

## Risks & Mitigations

- **Risk**: Direction 1's admit-on-designated-candidate change also relaxes Consequence A
  (removes 3 wasted cycles for a lone self-mod task), a larger behavioral change than a literal
  "fix the deadlock only" reading. **Mitigation**: this report re-derives the surviving hazards
  (1 and 3(i)) and shows neither is weakened by this relaxation, given the existing per-task-
  commit-before-redeploy sequencing guarantee. The plan should still size this as its own
  verification step: a dry-run fixture with 1 self-mod + 2 ordinary tasks, confirming immediate
  admission and confirming the redeploy checkpoint still only fires after all three commits land.
- **Risk**: moving the classifier call earlier in Stage MT-3 (Direction 2) could interact with an
  unnamed MT-3 invariant the task description flagged as unverified. **Mitigation**: this report
  verifies directly that nothing writes to `state.json` between the relocated classifier call and
  the existing Stage MT-4 call site within one cycle, so reuse (not re-invocation) is safe; no
  other MT-3 step reads the classifier's output today, so there is no other invariant to disturb.
  The plan should still add a regression fixture exercising a full cycle with a phase-map
  supplied, to catch anything this research missed.
- **Risk**: `reconcile-task-status.sh`'s new demotion logic is a new class of write for that
  script (the task description's own stated concern). **Mitigation**: scope it maximally
  narrowly — reached only after the existing no-artifact branch, gated on the lock-check exit
  code (never demote on exit 1 or exit 3), and log loudly on every demotion so it is never silent.
- **Risk**: re-measurement drift — the stranded task set (22, 28, 31) and the dead session id will
  likely have changed by implementation time. **Mitigation**: already flagged verbatim in the task
  description; this report's re-measurement is a snapshot for evidence, not a target to hard-code
  into fixtures — synthetic fixtures (as used by `test-orchestrate-triage-classify.sh`) are the
  correct testing mechanism, not the live stranded tasks themselves.

## Context Extension Recommendations

- **Topic**: the dependency-terminal-state vs. status-gate distinction within "the eligibility
  rule."
- **Gap**: `batch-orchestration-guardrails.md` and its co-maintenance set currently refer to "Stage
  MT-3 step 3's eligibility rule" as a single undifferentiated claim in several places, when it is
  actually two independent clauses with different change-sensitivity. This ambiguity is exactly
  what caused the task description to over-scope its "re-derive every safety argument" instruction
  relative to what this research found actually needs to change.
- **Recommendation**: when Work Stream A lands, add one sentence to
  `batch-orchestration-guardrails.md`'s "The Same-Cycle Narrowing and Its Hazard Accounting"
  subsection explicitly distinguishing "the dependency-terminal-state clause (item 4, unaffected
  by this task)" from "the former in-flight-status clause (item 3, removed by this task)," so a
  future reader auditing this rule again does not have to re-derive the same distinction from
  scratch.

## Appendix

### Search/verification commands used

```bash
jq -r '.active_projects[] | select(.project_number==22 or .project_number==28 or .project_number==31)' specs/state.json
bash .claude/scripts/task-lock.sh check 22   # and 28, 31
grep -n "eligible_tasks\|Stage MT-3\|Stage MT-4\|self_modifying\|deploy_checkpoint\|Decision 1\|blocked" skills/skill-orchestrate/SKILL.md
grep -n "enter.*researching\|leaves eligible_tasks\|self-clears" skills/skill-orchestrate/SKILL.md skills/skill-orchestrate-hard/SKILL.md docs/architecture/*.md commands/orchestrate.md context/patterns/batch-orchestration-guardrails.md
grep -n "structurally impossible\|researching.*planning\|eligib" docs/architecture/orchestrate-state-machine.md docs/architecture/batch-admit-schema.md commands/orchestrate.md
grep -n "task-lock\|acquire" scripts/command-gate-in.sh scripts/command-gate-out.sh
grep -n "cmd_check()" scripts/task-lock.sh
```

### File-by-file basis for the implementation plan

| File | Change |
|------|--------|
| `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` | Remove `{researching, planning}` exclusion at Stage MT-3 step 3 (line 1456); update phase-grouping table (1877-1885); converge single-task Stage 4 `researching`/`planning` handlers (359-367, 408-410) to dispatch; correct 3 convergence-exit-condition sites (1258, 1561, 1658); relocate classifier call earlier in Stage MT-3 step 4.5 and thread phase map into admission call and forward into Stage MT-4; implement designated-candidate awareness in the consumer-side branching (operator-facing log text at ~1541-1547 needs updating too) |
| `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md` | Mirror the admission-gate changes (already transcribes it in full); correct the 1 convergence-exit-condition site (1585); decide/transcribe researching/planning handler convergence (599-601, 689-691) |
| `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` | Add `researching`→`research`, `planning`→`plan` rows to the `jq` chain (currently falls into the else-arm at ~298-301) and header table (55-65) |
| `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` | Add fixtures for all previously-untested status→group rows, including the 2 new mutation-check rows |
| `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` | Add designated-candidate computation to the self_modifying branch (Direction 1); add `--phase-map` argument and phase-conditional defer (Direction 2) |
| `agent-system/extensions/core/scripts/reconcile-task-status.sh` | Add lock-aware demotion guard to `researching`/`planning` branches (Direction b), gated on `task-lock.sh check` exit code |
| `agent-system/extensions/core/scripts/parse-command-args.sh` | No edit (see Scope-narrowing findings) |
| `agent-system/extensions/core/commands/orchestrate.md` | No edit to the dependency-terminal-state claims; verify no independent restatement of the status-gate row exists (none found in this research beyond what's cited) |
| `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` | Add normative "ordering constraint not exclusion" subsection; add "considered and found already satisfied" note for Direction 3; add the dependency-vs-status clause distinction (Context Extension Recommendation above) |
| `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` | Add `reconcile-task-status.sh` entry only if Direction (b) lands; otherwise no edit |
| `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` | Remove `{researching, planning}` from the ASCII diagram (335-336) and Dependency Gating Model prose (379-382) |
| `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` | Correct the 1 convergence-exit-condition site (288); document the new `--phase-map` argument and its effect on the verdict schema |
