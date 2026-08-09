# Research Report: Task #899

**Task**: 899 - Author a batch-orchestration guardrails context pattern from current practice
**Started**: 2026-07-25T06:11:00Z
**Completed**: 2026-07-25T07:00:00Z
**Effort**: ~1.5h research
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/{commands,skills,scripts,context,docs}), WebSearch, WebFetch
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md

## Executive Summary

- The repository already implements a coherent, if unwritten and incomplete, admission-control
  discipline: creation-time dependency edges (Multi-Task Creation Standard 4a), a runtime
  wave-split check (`orchestrate.md` Step 3 / `SKILL.md` MT-3 step 4.5), and a per-task file lock
  (`task-lock.sh`) form three layers that together approximate a combined
  optimistic-pre-check-plus-pessimistic-lock concurrency strategy — a pattern the external
  concurrency-control literature explicitly recommends ("many production systems combine
  strategies"). This validates the existing three-layer shape; the gap is that its *governing
  principles* were never written down, and three concrete defects show where the unwritten
  reasoning already breaks.
- The **right criterion for blocking-vs-advisory** is not "cost of the check" alone but
  **(low-cost, structural, pre-dispatch fact) AND (harm is silent/hard-to-detect-later if
  ignored)**. All three existing admission checks (file-scope overlap, held lock, unmet
  predecessor) satisfy both halves and should stay blocking at any batch size.
- The **central tension in the task description has the wrong lever identified**: the fix for
  "a guardrail cheap at batch 1 stalls a batch of 8" is not to relax the guardrail to advisory as
  batch size grows — that is precisely the failure mode the human-in-the-loop literature
  documents as "approval fatigue" / "rubber-stamping" applied to machine gates. The fix already
  present in this codebase is to keep the check **blocking but scoped per-task/per-pair**
  (defer just the one colliding task), so a batch-of-8 guardrail hit costs one deferred task, not
  a stalled batch. Batch size should change the **scope of what gets deferred**, never the
  **existence** of the check.
- **Admission-time checks share one shape**: they are computable from already-on-disk structural
  state (state.json, `.lock/`, `file_scope`) without invoking any agent, so paying their cost
  before dispatch is nearly free. **Mid-flight checks share the opposite shape**: they require
  observing what a dispatched agent actually did (self-report vs. real artifact state, or a
  time-series across cycles), so they cannot be paid for at admission time.
- **Defer-not-fail is well-precedented** (wave-split, task-lock refusal) and generalizes cleanly:
  it should be the default response to every admission-time conflict, including the two newly
  identified defects (cross-batch lock-vs-unlocked collision, dropped out-of-batch dependency
  edges) — never a hard `failed` classification, which in this system's status vocabulary
  requires human intervention to reverse.
- **The clearest non-negotiable** is that a self-reported `dispatch_status="implemented"` must
  never be trusted as ground truth for `completed` — this is directly corroborated by 2026
  literature on autonomous coding agents ("transcript trust problem"; outcome-based verification)
  and is exactly the repository's own Defect 1.
- A downstream guardrail idea to reject explicitly: **indexing check strictness to batch size**
  (e.g., "make the wave-split check advisory once batch size exceeds N"). This conflates a
  human-review throughput problem (which legitimately benefits from batching/summarization, per
  the "piling problem" literature) with a machine correctness problem (which does not become
  cheaper or less necessary as concurrency increases — if anything the opposite).

## Context & Scope

This task's deliverable (a new context-pattern file,
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`) is written by
the later implementation phase, not by this research. This report grounds that deliverable in
(a) the actual, current behavior of `/orchestrate`'s batching machinery as read from source, and
(b) external material on admission control/backpressure, concurrency control over shared mutable
state, human-in-the-loop review at scale, and verification-gate design, current as of mid-2026.
Per the task's scope discipline, no skill/command/script/agent file was modified; this report
only reads.

## Findings

### Codebase Patterns (observed behavior)

**Three-layer admission architecture, already in place**:

1. **Creation-time (Multi-Task Creation Standard, Component 4a — `multi-task-creation-standard.md`
   lines 195-224)**: when several tasks are created together in one batch, `file_scope` is
   captured per task and the shared pairwise overlap algorithm
   (`context/patterns/file-footprint-overlap.md`) auto-adds a serializing `dependencies[]` edge
   for every overlapping pair with no existing edge. This makes tasks created *together*
   file-safe "for free" at Kahn's-algorithm wave-assignment time.
2. **Runtime, cross-batch (`orchestrate.md` Step 3 "Runtime wave-split check"; `SKILL.md` Stage
   MT-3 step 4.5)**: before dispatching any wave/cycle with 2+ tasks, every pair in that
   wave/cycle is compared with the same overlap algorithm, scoped to `file_scope` for tasks
   already collected into *this invocation's* `validated_tasks`/`task_numbers`. On overlap with no
   `dependencies[]` edge, the lower-priority task (higher `project_number`) is deferred to the
   next wave/cycle — never failed. This closes the gap Component 4a cannot: two tasks created in
   *separate* batches, each independently, with no creation-time comparison between them.
3. **Lock-acquisition-time (`task-lock.sh` `cmd_acquire`, lines 305-346)**: at per-task lock
   acquire, the acquiring task's `file_scope` is compared against every *other currently-held*
   lock's `file_scope`, repo-wide (`find_held_locks`) — not scoped to this invocation's task set.
   A fresh (non-stale) overlapping foreign lock causes refusal (return 1); a stale one gets a
   warning and proceeds. Same-session re-entry never blocks itself.

This layering is a real-world instance of the pattern the concurrency-control literature
describes as combining an optimistic, cheap pre-check (layers 1-2: decide whether to even attempt
concurrent dispatch, no lock taken) with a pessimistic enforcement lock (layer 3: `task-lock.sh`'s
mkdir-based mutex) — "many production systems combine strategies like MVCC as default with
pessimistic locks on known hot-spot rows" (see External Resources). The three layers are
independently sound. The problem this task addresses is that **the boundary between layers 2 and
3 is not fully closed**, and the *reasoning that should govern extending this architecture as
batch size grows* has never been written down.

**Three verified defects, and why they are admission-control gaps rather than one-off bugs**:

1. **Premature completion-claim promotion (Defect 1)** — `SKILL.md` Stage MT-4 step 3 maps
   `dispatch_status="implemented"` directly to `skill_postflight_update ... implemented` with no
   check of `phases_completed`/`phases_total`/`plan_markers_verified`. `handoff-schema.md`
   documents `plan_markers_verified` (optional bool) and specifies the exact warning behavior
   ("When `status = "implemented"` and `plan_markers_verified` is absent or `false`, the
   orchestrator logs a warning ... This warning does not block the next lifecycle phase") — but
   this warning is implemented nowhere in Stage MT-4 (nor, per the single-task Stage 5 code read
   for comparison, in the single-task path). This is a **mid-flight verification gap**: it can
   only be caught by comparing the agent's self-report against the actual plan-file/artifact
   state after the agent returns — never before dispatch.
2. **Invisible collision between an in-batch task and a non-terminal, unlocked, out-of-batch task
   (Defect 2)** — `orchestrate.md` Step 3 and `SKILL.md` MT-3 step 4.5 both scope their overlap
   comparison to `validated_tasks`/`task_numbers` (this invocation's set); `task-lock.sh` only
   compares against currently-**locked** tasks (`find_held_locks`). A task with overlapping
   `file_scope` that is neither in this batch nor currently holding a lock (e.g., a `researched`
   or `planned` task sitting idle, about to be separately worked on) is invisible to all three
   layers simultaneously. This is an **admission-control gap**, not a mid-flight one — the
   overlapping `file_scope` is static, on-disk data (`state.json`), fully knowable before any
   dispatch; the gap exists because no layer's scan window includes "every non-terminal task in
   `state.json`," only "every task in this invocation" or "every currently-locked task."
3. **Silently dropped out-of-batch dependency edges (Defect 3)** — `orchestrate.md` Step 2
   explicitly restricts the dependency graph to intra-batch edges ("ignore dependencies on tasks
   not in `validated_tasks`"). A declared dependency on a task outside the batch is not deferred,
   not warned about, and not surfaced anywhere — it is silently treated as satisfied. This is also
   an **admission-control gap**: the dependency is declared, on-disk data (`state.json`
   `.dependencies[]`), fully knowable before dispatch; the defect is that the graph-construction
   step discards information it already has rather than acting on it.

Both Defects 2 and 3 are pre-dispatch, structurally-detectable gaps in scan scope — not new kinds
of check, but the existing checks silently narrowed to "this invocation only." Defect 1 is
categorically different: it is a mid-flight, outcome-verification gap that cannot be closed by
widening a scan window, because the fact it needs (did the agent actually finish all phases) does
not exist until the agent has run.

**`.orchestrator-handoff.json`'s 400-token budget** (`handoff-schema.md`) is itself a governing
constraint on any future guardrail design: whatever admission or mid-flight signal a guardrail
adds must fit inside this budget if it needs to reach the state machine loop, since Stage
5/MT-4's "Context Flatness Constraint" (`SKILL.md` "MUST NOT" section) forbids reading anything
but the handoff file after each dispatch. `plan_markers_verified` already lives inside this
budget as a single boolean — a template for how future mid-flight signals (e.g., a churn counter)
should be represented: compact, boolean-or-small-integer, not prose.

### External Resources

**Admission control and backpressure** (multi-agent orchestration, 2026 secondary sources):
production multi-agent orchestration guidance treats backpressure, budgets, and blame as
first-class operational concerns coequal with agent logic itself, not an afterthought layered on
later — see the "12 agent orchestration rules for backpressure, budgets, and blame" survey and
TrueFoundry's discussion of gateway-level access/cost controls across orchestration frameworks.
This validates treating admission control as a documented, principled subsystem (this task's
deliverable) rather than ad hoc per-invocation judgment.

**Concurrency control over shared mutable state**: optimistic concurrency control (OCC) assumes
conflicts are rare, proceeds without locking, and checks/rolls back at commit time; pessimistic
locking blocks proactively. The literature's guidance — "when conflicts are rare... optimistic
control delivers better throughput; when conflicts are frequent, the retry overhead makes
pessimistic control more efficient," and "many production systems combine strategies" — directly
supports this repository's existing combination (cheap pairwise pre-check to avoid dispatching
conflicting pairs at all, pessimistic mkdir-lock to enforce the boundary once dispatched). No
external source recommends abandoning either half at scale; the recommendation is always to
combine them, which is what this repo already does. (Sources: Databricks "Concurrency Control in
DBMS"; Wikipedia "Optimistic concurrency control"; ScalableThread newsletter on OCC handling.)

**Human-in-the-loop review at batch scale — batch vs. per-item approval and failure modes**: two
consistent, mutually-reinforcing external sources describe the same failure mode from different
angles.
- Per-item approval degrades under volume: "approval fatigue... within 48 hours of requiring
  human approval for every single agent action, a queue had 14,000+ pending items, average
  approval latency jumped to 6.4 hours, reviewers started rubber-stamping after day 3 (approval
  rate hit 99.7%)." The fix is not "approve everything faster" but to "reserve human review for
  irreversible, high-impact, or policy-violating actions" and batch/automate the rest — placing
  human judgment "where it still matters, not where it erodes into reflex."
  ([nhimg.org](https://nhimg.org/faq/what-breaks-when-human-in-the-loop-approval-becomes-routine-for-ai-agents/))
- The "piling problem": agent throughput routinely outpaces human review capacity as deployments
  scale past pilot size (20-30 outputs -> 500+/day), and the resulting overload causes reviewers
  to "rubber-stamp outputs without meaningful review, defeating automation's purpose and allowing
  errors to compound undetected." Recommended mitigations: size batch/run-frequency to actual
  reviewer capacity (not technical maximum), tiered review (auto-approve high-confidence, spot
  check medium, full review low-confidence), and demand-driven ("downstream signals when ready
  for more") rather than supply-driven throughput.
  ([MindStudio, "What Is the Piling Problem in AI Agent Workflows?"](https://www.mindstudio.ai/blog/piling-problem-ai-agent-workflows))

**Important scope distinction these sources support**: both describe *human* review degrading
under volume — they are about the batch git-commit/consolidated-output summary a human reads
*after* an `/orchestrate` batch finishes (`orchestrate.md` Step 5), not about the *machine*
admission checks that decide whether two tasks may run concurrently. Batching is the right answer
for the former (a human should see one consolidated table, not 8 separate approval prompts) and
the wrong answer for the latter (a machine overlap check does not get harder to run, or less
necessary, as batch size grows — see Decisions below).

**Verification-gate design for autonomous agents**: 2026 guardrail-design guidance converges on
"separating verdict from action, letting the agent decide, but gating any irreversible action,"
with risk-based tiers (light oversight for reversible/low-risk, multi-step verification + audit
trail for high-impact) and an operational-discipline framing: guardrails are not "one-time
configuration" but ongoing practice aimed at "making failures small and reversible rather than
attempting to prevent all failures" (Atlan, Torq, Reco 2026 guardrail guides). This directly
supports **defer-not-fail** as a design default: a deferred task is a small, fully reversible
failure (it simply runs later); a hard `failed` classification is not reversible without human
intervention.

**Self-reported completion is not evidence of completion** — directly relevant to Defect 1. Two
2026 sources converge: autonomous coding-agent orchestration tooling that "verif[ies] work by
reading transcripts... trusting the agent's self-report" reliably misses real failures ("a
half-written JWT helper, no tests, and a build that doesn't compile" reported as done); the fix is
"outcome-based verification" — checking actual git diff / build exit code / test results / file
existence, with self-report "demoted to supplementary-only status," and gating any
merge/completion decision on those checks, never on narration alone.
([dev.to, "AI coding agents lie about their work"](https://dev.to/moonrunnerkc/ai-coding-agents-lie-about-their-work-outcome-based-verification-catches-it-12b4);
see also the "hallucinated progress... undetectable" framing in broader hallucination-detection
coverage.) This is precisely what `plan_markers_verified` is designed to be — a cheap, structural
outcome check (are all phase headings actually `[COMPLETED]`) rather than trusting
`dispatch_status="implemented"` alone — and precisely what Defect 1 shows is not actually wired
into the postflight decision.

**Circuit breaker / defer-vs-fail-fast** (Microsoft Learn, Azure Architecture Center — durable,
canonical reference): the pattern's core distinction is between *transient* faults (retry-worthy,
typically self-correcting) and faults requiring the caller to "quickly recognize the failed
operation and handle the failure accordingly" (fail fast) rather than block resources waiting.
Two details generalize cleanly to task admission:
- "Failed request replay: In the Open state, rather than failing immediately, a circuit breaker
  can record the details of each request in a journal and arrange for these requests to be
  replayed when the... service becomes available" — structurally identical to deferring a task to
  the next wave/cycle rather than failing it.
- Explicit non-fit: "You need to manage access to local private resources... a circuit breaker
  adds overhead," and "message-driven or event-driven architectures... often route failed
  messages to a dead letter queue for manual or deferred processing" instead of tripping a
  breaker. Task admission in this repo is closer to this second case — a single-process,
  file-based coordination problem — which is consistent with `task-lock.sh`'s simpler
  heartbeat-staleness override rather than a full closed/open/half-open state machine; adopting a
  literal circuit-breaker state machine for task admission would be over-engineering relative to
  what the problem needs.

## Decisions

These are explicit conclusions from grounding both sides (codebase + external), stated for the
implementation phase to consult directly rather than re-derive:

1. **Blocking-vs-advisory criterion**: a guardrail is BLOCKING (refuse to dispatch, i.e. defer)
   when it is (a) computable purely from on-disk structural state without invoking any agent, AND
   (b) the harm of proceeding anyway is silent and hard to detect after the fact (concurrent file
   corruption, acting on stale context, an unmet dependency treated as met). All three existing
   pre-dispatch checks — file-scope overlap, held lock, unmet predecessor — satisfy both
   conditions and must remain blocking regardless of batch size. A guardrail is ADVISORY (warn,
   continue) when the underlying signal is inherently a heuristic/estimate rather than a hard
   fact (e.g., a drift-percentage from a fork's plan inspection) or when the condition being
   warned about is not this invocation's to fix (e.g., logging that `plan_markers_verified` was
   absent, per `handoff-schema.md`'s own documented "does not block the next lifecycle phase"
   behavior) — but "advisory" never means "unlogged" or "silent."
2. **Batch size changes scope of deferral, not existence of the check.** The task description's
   framing — "a guardrail cheap enough to be blocking at batch size 1 may stall an entire batch at
   size 8" — names a real cost problem but the wrong fix. The existing wave-split/lock-defer
   mechanism already solves it correctly: on conflict, defer the ONE lower-priority task, not the
   batch. Any future guardrail should be designed the same way — per-pair or per-task granularity
   of consequence — so that a batch of 8 never pays more than "1 task deferred" for any single
   conflict, and the check's existence is therefore orthogonal to `MAX_TASKS`. Relaxing a
   correctness check to advisory as batch size grows is the literal mechanism by which the
   human-in-the-loop literature's "approval fatigue" failure mode would enter machine admission
   control — this is explicitly the wrong direction and should be documented as a rejected
   approach, not a tunable.
3. **Pre-dispatch vs. mid-flight classification is a knowability test, not a cost test.** A
   problem belongs to admission control if and only if the fact needed to detect it already
   exists on disk before any agent is invoked (file_scope, dependency edges, lock holder,
   handoff-file mtime). A problem belongs to mid-flight detection if and only if the fact needed
   only exists after an agent has acted (what the agent actually wrote vs. what it claimed;
   whether phase headings actually flipped to `[COMPLETED]`; a trend across 2+ cycles such as
   churn). Under this test: file-footprint collision, stale handoff, held lock, and unmet
   predecessor are unambiguously admission-control (all four defects/checks discussed above are
   examples). Premature completion claims, churn, and drift are unambiguously mid-flight (drift
   inspection, Stage 5a, already implements this correctly for its one case).
4. **Defer-not-fail is the standing default for every admission-time conflict**, not just the two
   already implemented. This includes both newly-identified defects: a task colliding with a
   non-terminal unlocked out-of-batch task should be excluded from this dispatch cycle (deferred),
   not failed; a task whose dependency lies outside the batch should be excluded from the batch
   with a visible warning (deferred pending a future invocation that includes the predecessor),
   never silently treated as satisfied and never hard-failed. Rationale: admission conflicts are
   transient by construction (they resolve once the colliding/blocking task terminates), and this
   system's `failed`/`blocked` states require human intervention to clear — disproportionate for a
   scheduling conflict.
5. **Non-negotiables** (never relaxed for throughput, at any batch size):
   - Never promote to `completed`/postflight-implemented on a bare `dispatch_status="implemented"`
     self-report; an outcome check (`plan_markers_verified` or equivalent) must gate it. Self-report
     is supplementary evidence only, never sufficient evidence, per the outcome-based-verification
     grounding above. This directly closes Defect 1.
   - Never narrow file-footprint/lock overlap scanning to "this invocation's task set" as the
     *only* scope; the scan must also reach non-terminal, currently-unlocked tasks outside the
     batch. Correctness of concurrent-write detection does not get cheaper as concurrency
     increases — it becomes more necessary. This directly closes Defect 2.
   - Never silently drop a dependency edge because its target is out of batch; at minimum warn
     loudly and exclude the dependent task by default. Silent drop is the exact "no consequence"
     failure the audit-trail/verification literature warns against. This directly closes Defect 3.
   - Never let human-facing batch-approval (legitimate and recommended for the consolidated
     post-hoc summary a human reads) substitute for or gate machine admission decisions. Which
     tasks may run concurrently is a deterministic, per-pair, machine-checked question,
     independent of whether or how a human later reviews the batch's outcome.
   - Never treat `MAX_TASKS` as a correctness control. It bounds human cognitive load over the
     consolidated output table (a piling-problem-style backpressure control on the *reviewer*),
     not the soundness of per-pair admission checks. Raising `MAX_TASKS` is safe only if the
     human-facing review/summarization strategy scales with it — the two must be reasoned about
     separately, and conflating them (e.g., "our per-pair checks are O(n^2) but cheap, so
     `MAX_TASKS` can rise arbitrarily") ignores the orthogonal, unsolved reviewer-throughput
     question.

## Risks & Mitigations

- **Risk**: a future implementation reads "blocking is expensive at scale" and responds by adding
  a batch-size-indexed advisory threshold to an existing blocking check (e.g., wave-split or
  lock-overlap). **Mitigation**: the deliverable context pattern must state Decision 2 explicitly
  and by name as a rejected approach, not merely imply it, so it cannot be independently
  rediscovered and adopted by a later, less-grounded pass.
- **Risk**: closing Defect 2 (widen the overlap scan beyond the current invocation) could be
  implemented as a repo-wide, real-time scan on every wave/cycle, which would reintroduce exactly
  the batch-stalls-on-cheap-check problem this task is trying to prevent, if done at O(all
  non-terminal tasks) x O(all non-terminal tasks) per cycle. **Mitigation**: the deliverable
  should note that the *task-lock.sh* precedent (task 809) already extended a bounded scan
  (currently-held locks only) rather than an unbounded one (all specs/); any Defect-2 fix should
  follow the same bounded-scope discipline (e.g., scan non-terminal tasks, not every task in
  specs/ including completed/abandoned ones) — this is a design note for the future admission-
  machinery task, not something to resolve here.
- **Risk**: Decision on Defect 3 leaves open whether the correct response is "exclude the
  dependent task from the batch" or "auto-expand the batch to include the out-of-batch
  predecessor." Both are defer-not-fail-compatible; they differ in blast radius (exclude one task
  vs. silently grow the batch, which itself needs its own admission checks). **Mitigation**: flag
  this as an open design fork for the implementation/admission-machinery phase rather than
  resolving it here, consistent with this task's scope discipline (one new context file, no
  behavior change).
- **Divergence between external HITL literature and this repo's actual design**: the reviewed
  human-in-the-loop sources assume a human is available to escalate genuinely ambiguous/high-stakes
  items to, synchronously, during the run. `/orchestrate`'s design explicitly assumes the opposite
  — "No confirmation gates between lifecycle phases" and no human present mid-run — and instead
  uses a capped automated escalation-fork sequence (Stage 6, `MAX_BLOCKER_ESCALATIONS=2`) followed
  by an eventual give-up-and-report-to-human-asynchronously (via git commit / `[PR READY]` status,
  per the PR/push prohibition rule that only a human invokes `/merge`). This is a real design
  divergence, not a smoothing-over: this repo does not have a synchronous "batch approval" gate in
  the external literature's sense at all today; the closest analog (`orchestrate.md` Step 5's
  consolidated output) is purely informational, after the fact. The deliverable should say this
  plainly rather than implying an approval gate exists where none does.

## Context Extension Recommendations

None beyond this task's own deliverable. The gap this task addresses — no principle-level
(as opposed to mechanism-level) documentation of batch admission control — is exactly what
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` is meant to
fill; `file-footprint-overlap.md` and (implicitly) `task-lock.md` remain the correct
mechanism-level references and should be cross-referenced by path from the new pattern file
rather than restated.

## Appendix

### Codebase files read

- `agent-system/extensions/core/commands/orchestrate.md` (Steps 1-5, Checkpoints 1-3)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stages 0-8, MT-1 through MT-5,
  MUST NOT / Context Flatness Constraint)
- `agent-system/extensions/core/scripts/task-lock.sh` (`cmd_acquire`, lines ~290-388)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (full)
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (full)
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
  (Component 4a, lines ~195-224)
- `specs/state.json` (task 899's own entry, for task_type/file_scope confirmation)

### Search queries used

- "multi-agent orchestration admission control backpressure 2026"
- "concurrency control shared mutable state optimistic locking distributed systems best practices"
- "human-in-the-loop batch approval versus per-item approval AI agents failure modes"
- "verification gate design autonomous AI agents 2026 guardrails blocking advisory"
- "AI agent self-reported task completion verification hallucinated success autonomous coding agents"
- "circuit breaker defer not fail admission control queueing job scheduler design pattern"
- "agentic workflow batch size scaling review bottleneck quality regression unnoticed"

### Sources fetched in full

- [Circuit Breaker Pattern — Azure Architecture Center, Microsoft Learn](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [What breaks when human-in-the-loop approval becomes routine for AI agents?](https://nhimg.org/faq/what-breaks-when-human-in-the-loop-approval-becomes-routine-for-ai-agents/)
- [What Is the Piling Problem in AI Agent Workflows? — MindStudio](https://www.mindstudio.ai/blog/piling-problem-ai-agent-workflows)
- [AI coding agents lie about their work. Outcome-based verification catches it. — dev.to](https://dev.to/moonrunnerkc/ai-coding-agents-lie-about-their-work-outcome-based-verification-catches-it-12b4)

### Additional sources referenced from search snippets (not individually fetched)

- [Optimistic concurrency control — Wikipedia](https://en.wikipedia.org/wiki/Optimistic_concurrency_control)
- [Concurrency Control in DBMS: How Locking, MVCC and Optimistic Strategies Keep Data Consistent — Databricks](https://www.databricks.com/blog/concurrency-control)
- [How to Handle Concurrency with Optimistic Locking? — Scalable Thread newsletter](https://newsletter.scalablethread.com/p/how-to-handle-concurrency-with-optimistic)
- [12 agent orchestration rules for backpressure, budgets, and blame — Medium](https://medium.com/@hadiyolworld007/12-agent-orchestration-rules-for-backpressure-budgets-and-blame-3b07c942b2dc)
- [6 Multi-Agent Orchestration Patterns for Production (2026) — beam.ai](https://beam.ai/agentic-insights/multi-agent-orchestration-patterns-production)
