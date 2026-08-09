# Research Report: Task #901

**Task**: 901 - Add an orchestrate dry-run that reports batch admission verdicts before dispatch
**Started**: 2026-07-25T00:00:00Z
**Completed**: 2026-07-25T00:00:00Z
**Effort**: Medium (one new script + wiring into two existing files; logic is mostly composition of already-built primitives)
**Dependencies**: 900 (orchestrate-batch-admit.sh, completed — the collision half of this task's data source)
**Sources/Inputs**:
- Codebase: `scripts/orchestrate-batch-admit.sh`, `docs/architecture/batch-admit-schema.md`, `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `docs/architecture/orchestrate-state-machine.md`, `docs/architecture/handoff-schema.md`, `scripts/parse-command-args.sh`, `scripts/task-lock.sh`, `context/patterns/task-lock.md`, `context/patterns/batch-orchestration-guardrails.md`, `context/patterns/file-footprint-overlap.md`, task 900's plan/summary/tests
- WebSearch: approval-fatigue and dry-run-trustworthiness literature (July 2026)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `--dry-run` should be a thin *reporting* wrapper around the exact same admission data the live
  path already computes — `orchestrate-batch-admit.sh` (file-scope collisions, done by task 900)
  plus two NEW read-only checks this task must add: predecessor-unmet and lock-held. The
  handoff-triage classification (continuation / blockers / no-handoff) is a *separate* concern
  layered on top, and it is the part most likely to drift from live behavior if implemented
  independently rather than extracted from the same source the live dispatch reads.
- **Critical finding, must be resolved before design**: the task's own acceptance criterion says
  "the triage classifier must agree with [Stage MT-4's] table exactly." That MT-4 table's row
  `partial with no handoff -> implement_tasks (dispatch)` genuinely **contradicts** the
  single-task Stage 4 handler for the identical condition, which instead **exits the whole
  invocation** ("Sub-state: no handoff, no blockers" -> `EXIT (partial, cycle_count)`, telling the
  user to re-run manually — SKILL.md lines 410-416) and the parallel state-table row in
  `orchestrate-state-machine.md` ("partial (no handoff, cycle limit)" -> "Report state, exit").
  Since `/orchestrate` routes to genuinely different code (single-task Stage 1-8 vs. multi-task
  Stage MT-1-5) purely by argument count (`len(TASK_NUMBERS) == 1` vs. `> 1`), a triage classifier
  that always applies MT-4 semantics will be **wrong** for a single-task `--dry-run` invocation.
  See Findings > "Which table governs" for the two resolution options.
- `--dry-run` is a well-established convention in this codebase already (`/refresh`, `/tag`,
  `/todo`, `update-task-status.sh`, `reconcile-task-status.sh`, `reconcile-artifacts.sh`,
  `archive-task.sh`) but is **absent from `parse-command-args.sh`** — it must be added there
  (a `DRY_RUN_FLAG` alongside `CLEAN_FLAG`/`FORCE_FLAG`, in both the flag-scan block and the
  `FOCUS_PROMPT`-stripping `sed` chain) rather than ad hoc string matching, per the task's own
  instruction.
- Two of the four required exclusion reasons already have a read-only primitive to reuse:
  file-scope collision -> `orchestrate-batch-admit.sh` (task 900, done); lock held by another
  session -> `task-lock.sh check <task_number>` (pure read, exit 0/1/2/3, never `acquire`).
  Unmet predecessor is a straightforward dependency-graph read already spelled out in
  `orchestrate.md`'s wave-assignment steps. None of these three write anything.
- The web research on dry-run/plan-preview trust (below) converges on one actionable principle:
  a preview that never shows a negative case trains its reader to stop reading it. The report's
  format should make the exclusion table structurally impossible to omit or collapse when empty
  — never a bare "0 excluded" — and should visually/textually distinguish "nothing to report"
  from "did not check."

## Context & Scope

Task 901 adds a `--dry-run` flag to `/orchestrate` that performs the *same* admission analysis
the live multi-task path already performs before dispatching a wave/cycle, but only prints a
report — no state.json writes, no TODO.md regeneration, no lock acquisition, no Agent dispatch.
It depends on task 900 (`orchestrate-batch-admit.sh`, already implemented and merged) for the
file-scope-collision half of the analysis, and shares three files with the still-`not_started`
task 902 (which will add a self-modification solo-only gate on top of the same admission script
and command file — out of scope here, but the design should not foreclose it).

This report focuses on: (1) how the flag should be parsed, (2) what data sources already exist
vs. must be newly read, (3) the exact handoff-triage precedence the classifier must reproduce and
the discrepancy that must be resolved before design, (4) the read-only constraint and which
existing helpers are safe vs. unsafe to call in dry-run mode, and (5) what makes a preflight
report trustworthy rather than a rubber stamp, per current external practice.

## Findings

### Codebase Patterns

**`--dry-run` is an established, well-worn convention — but not yet in the shared arg parser.**
`commands/refresh.md`, `commands/tag.md`, `commands/todo.md` all document `--dry-run` at the
command level; `scripts/update-task-status.sh`, `scripts/reconcile-task-status.sh`,
`scripts/reconcile-artifacts.sh`, and `scripts/archive-task.sh` all implement a `DRY_RUN`
shell variable with the same shape: parse the flag, and every mutating step is guarded by
`if [[ "$DRY_RUN" == "true" ]]; then echo "[dry-run] Would ..." ; else <actual mutation> ; fi`.
`scripts/parse-command-args.sh`, however, has no `DRY_RUN_FLAG` today — its exported variable
set is `TASK_NUMBERS`, `REMAINING_ARGS`, `TEAM_MODE`, `TEAM_SIZE`, `EFFORT_FLAG`, `MODEL_FLAG`,
`CLEAN_FLAG`, `FORCE_FLAG`, `LOCAL_FLAG`, `EXPLOIT_FLAG`, `EXPLORE_FLAG`, `LIT_FLAG`,
`FOCUS_PROMPT`. Adding `DRY_RUN_FLAG` means touching three spots in that one file: the
default-initialization block, a new `if [[ "$remaining" =~ --dry-run ]]; then DRY_RUN_FLAG="true"; fi`
check, and appending `| sed 's/--dry-run//g'` to the `FOCUS_PROMPT`-stripping `sed` pipeline —
plus adding `DRY_RUN_FLAG` to the final `export` line. This is a small, mechanical, low-risk
change and is exactly the "established argument-parsing path" the task description points at.

**The file-scope-collision half of the analysis already exists and is reusable as-is.**
`scripts/orchestrate-batch-admit.sh` (task 900) is already a pure, read-only, NDJSON-emitting
predicate: `orchestrate-batch-admit.sh <task_number> [<task_number> ...]` reads
`specs/state.json` exactly once and prints one `orchestrate-batch-admit-v1` verdict per
candidate — `admit` or `defer`, and on `defer`, `colliding_task_number`, `colliding_task_status`,
`overlapping_path`, `collision_scope` (`in_batch`/`cross_batch`), and a templated `reason`
string. It is already wired into both `commands/orchestrate.md` Step 3 (pre-computed wave
schedule, called once per wave) and `skills/skill-orchestrate/SKILL.md` Stage MT-3 step 4.5
(called once per cycle against `eligible_tasks`). This script is exit-2/no-verdicts on usage
error or unavailable state, and otherwise always exit-0 regardless of decision — it never
mutates anything and is already safe to call from a dry-run path unchanged. It is the natural,
single source of truth for the "file_scope collision" exclusion reason and (with wave
computation layered on top, see below) the "recommended split" surface.

**Lock-held detection already has a pure-read primitive: `task-lock.sh check`.** The task
description explicitly warns "`task-lock.sh` in particular must not be called in acquire mode."
`task-lock.sh` already exposes exactly the read-only alternative needed:
`task-lock.sh check <task_number>` prints `free` (exit 0), `held-fresh session=... heartbeat_age_min=... threshold_min=...`
(exit 1), or `held-stale session=... heartbeat_age_min=... threshold_min=...` (exit 2), or a
usage error (exit 3) — and never writes to `.lock/holder.json`. One nuance the classifier must
apply: `check` does not compare `session_id` (unlike `acquire`'s same-session-re-entry rule), so
a dry-run's exclusion reason should compare the reported `session=` value against the current
session before excluding a task — a task whose lock happens to be held by *this same* session
(e.g. a `/plan N` invocation immediately followed by `/orchestrate N --dry-run` in one
conversation) is not actually contended and should not be reported as excluded. A `held-stale`
result (exit 2) is informationally different from `held-fresh` (exit 1): `acquire` itself would
override a stale lock and proceed, so a dry-run reporting a *stale* lock as an exclusion reason
would misrepresent what the live path will actually do. Recommend surfacing `held-stale` as a
non-excluding informational note (or a distinct, weaker reason) rather than folding it into the
same "lock held by another session" exclusion bucket as `held-fresh`.

**Unmet-predecessor detection is already fully spelled out, just not yet extracted into a
reusable predicate.** `commands/orchestrate.md`'s "MULTI-TASK DISPATCH" Steps 1-3 (Batch
Validation, Dependency Graph Construction, Topological Wave Assignment / Kahn's algorithm) are
the live source of the wave computation the dry-run report must reproduce verbatim: intra-batch
dependency edges only, circular-dependency detection, and the same `wave_assignment` map used
for the actual dispatch order. Because `orchestrate-batch-admit.sh` already independently
excludes cross-batch collisions using *global* (not just intra-batch) dependency edges (in
either direction), the dry-run's predecessor check and its collision check are not fully
independent — a candidate task with a dependency edge to a task outside the batch is exactly
the case task 900's "excluding a dependent task by default" language (see
`batch-orchestration-guardrails.md` Non-Negotiable 3) already contemplates, and is presently an
*open design fork*, not a decided behavior (same document, "Open Design Fork" section: whether
to exclude the dependent task or auto-expand the batch is explicitly left unresolved). The
dry-run report should surface this case under "unmet predecessor" with the predecessor's status,
distinguishing "predecessor is in this batch and not yet terminal" from "predecessor is NOT in
this batch at all" (an out-of-batch dependency), mirroring the `in_batch`/`cross_batch`
distinction `orchestrate-batch-admit.sh` already established for collisions — for consistency of
vocabulary and because the same underlying open design question applies.

**The blocking-vs-advisory criterion and the "knowability" framing are already codified and
apply cleanly to all four exclusion reasons.** `context/patterns/batch-orchestration-guardrails.md`
gives a two-part test (computable from on-disk state without invoking an agent, AND the harm of
skipping it is silent/hard-to-detect-later) and an explicit "Admission-Time vs. Mid-Flight:
A Knowability Test" section that already lists all four of this task's exclusion categories as
admission-time facts: "File-scope collision," "Held lock," "Unmet predecessor," and — directly
on point — **"Stale handoff — the handoff file's mtime is already on disk."** This confirms the
task's own framing (report-only, no agent invocation) is squarely inside the existing
"admission-time" classification, and gives a textually-anchored justification for why this
report can be computed with zero Agent-tool calls.

### Handoff Triage: Exact Precedence and the Discrepancy That Must Be Resolved

The single-task Stage 4 handler (`skill-orchestrate/SKILL.md` lines 359-416) spells out the
`partial`-substate classification in full, with an unambiguous **precedence order**:

1. **Continuation available**: `continuation_context != null` AND it has `handoff_path` ->
   dispatch to implement (regardless of whether blockers are also present).
2. **Blockers present** (checked only if #1 did not fire): `blockers` array non-empty -> invoke
   blocker escalation (Stage 6).
3. **Neither present** (checked only if neither #1 nor #2 fired): "no continuation and no
   blockers" -> **EXIT the entire invocation** with `partial` status and a message telling the
   user to re-run `/orchestrate N` or fall back to manual `/implement N`. This happens even if
   `cycle_count < MAX_CYCLES` — it is a hard stop for this dispatch, not a "try again next
   cycle" branch. `docs/architecture/orchestrate-state-machine.md`'s Complete State Table
   confirms this at row "`partial` (no handoff, cycle limit)" -> "Report state, exit."

The task description restates this exact precedence in its own words ("a task in partial status
whose `.orchestrator-handoff.json` carries unresolved blockers and NO `continuation_context`
routes to blocker escalation rather than productive work") — confirming rule #2 above as the
"needs-human" case this task's triage classifier must reproduce.

`skill-orchestrate/SKILL.md`'s Stage MT-4 "Phase grouping" table (lines 1008-1018), which is the
table the task names explicitly as the agreement target, encodes the SAME first two rows
identically:

| Task status | Group |
|---|---|
| `partial` with continuation | implement_tasks (dispatch) |
| `partial` with blockers | failed_tasks (mark blocked) |
| `partial` with no handoff | implement_tasks (dispatch) |

but its **third row disagrees with the single-task behavior for the identical underlying
condition** — where single-task Stage 4 exits the whole invocation, MT-4 dispatches to implement
anyway (consistent with MT mode's per-cycle retry budget, `MAX_CYCLES_MT`, rather than a
one-shot-per-invocation model). No code block in Stage MT-3/MT-4 shows the literal mechanism
that decides "blockers present" *before* dispatch composition for a partial task in MT mode
(unlike the single-task path, which reads `blockers`/`continuation` explicitly at lines
361-368); this row appears to be a specification the implementation must still satisfy, not
an already-implemented branch. This is exactly the sort of gap the task's "VERIFY BEFORE
DESIGNING" instruction anticipates, and resolving it is squarely in scope for the plan.

**Why this matters for `--dry-run` specifically**: `/orchestrate` routes to single-task Stage 1-8
or multi-task Stage MT-1-5 purely by argument count (`orchestrate.md` Stage 0: `len(TASK_NUMBERS)
== 1` vs `> 1`) — these are genuinely different code paths with, as shown above, different
partial-substate outcomes for the identical "no continuation, no blockers" condition. A `--dry-run`
report is explicitly a *prediction of what the live path will do*. If the classifier always
applies MT-4 semantics (as the task's acceptance criterion asks), a `/orchestrate 905 --dry-run`
(single task, no comma) would predict "admit, dispatch to implement" for a task genuinely in that
edge case, while the ACTUAL live `/orchestrate 905` (no `--dry-run`) would take the single-task
path and immediately exit `partial` instead. This is precisely the "confidently wrong" failure
the task description warns against, and it is not hypothetical — it follows directly from reading
both code paths side by side. Two resolution options, to be decided at plan time:

- **(A) Branch the classifier on batch size, matching whichever engine will actually run.**
  Read `TASK_NUMBERS` the same way `orchestrate.md` Stage 0 does; for a single task apply the
  single-task Stage 4 precedence (continuation -> dispatch; blockers -> escalate; neither ->
  EXCLUDE as "needs-human, would exit"); for 2+ tasks apply the MT-4 table (continuation ->
  dispatch; blockers -> exclude as needs-human; neither -> ADMIT/dispatch). This keeps the report
  accurate for both invocation shapes at the cost of two branches instead of one.
- **(B) Scope `--dry-run`'s full admission-report framing (wave assignment, admitted set,
  recommended split) to multi-task invocations only**, since the task description's own report
  contents ("admitted set with wave assignment," "recommended split") only make sense for a batch
  of 2+ tasks; for a single task number, `--dry-run` could print a simpler single-task preview
  (current status, which of the 3 single-task sub-states would fire) using the single-task
  precedence, never invoking the MT-4 table at all.

Option (A) is more uniform in code shape (one script, two precedence tables selected by branch);
option (B) is more honest about the fact that a batch-of-one dry-run and a real multi-task batch
genuinely exercise different engines. Either is compatible with "one code path, two consumers"
as long as the *live* dispatch and the *dry-run* report read the identical branch condition
(argument count) to decide which precedence table applies — the risk to avoid is a dry-run
classifier that is blind to this branch and always assumes MT-4 semantics.

### Read-Only Constraint: What Is Safe to Call, What Is Not

Confirmed safe (pure reads, already exist):
- `orchestrate-batch-admit.sh <task_numbers...>` — read-only by construction (task 900); never
  writes; safe to call as-is.
- `task-lock.sh check <task_number>` — read-only; distinct from `acquire`; never touches
  `holder.json`. The dry-run MUST call `check`, never `acquire` (the task description's explicit
  warning) — `check`'s own header comment confirms it never blocks or mutates.
- Reading `.orchestrator-handoff.json` directly via `cat`/`jq` — this is the existing, documented
  ~400-token-budget read every live cycle already performs (`handoff-schema.md`'s Reading
  Contract); reading it for a dry-run preview is the same read, just earlier and without a
  subsequent dispatch.
- Reading `specs/state.json` for status/dependencies/`file_scope` — already the read every
  existing admission check performs.

Confirmed UNSAFE for dry-run (mutating, must be skipped or explicitly dry-run'd):
- `scripts/skill-base.sh`'s `skill_preflight_update` / `skill_postflight_update` /
  `skill_link_artifacts` / `skill_gate_completion_claim` — all write state.json and/or TODO.md.
  Not applicable to a report-only path at all.
- `scripts/reconcile-task-status.sh` — the existing live call sites in `skill-orchestrate/SKILL.md`
  (single-task entry reconcile at line ~192, and the per-task MT-2 entry reconcile at line
  ~917) invoke it **without** `--dry-run`, because in normal orchestration a stranded-status
  repair is a legitimate, desired write. A `--dry-run` invocation must either skip this reconcile
  step entirely, or call it WITH its own `--dry-run` flag (which it already supports) if the
  report wants to surface "this task's status looks stranded and would be reconciled" as
  informational text — never call it live from the dry-run path.
- `scripts/task-lock.sh acquire` — explicitly named in the task description as prohibited.
- `scripts/update-task-status.sh` and `scripts/generate-todo.sh` — never invoked at all by a
  read-only report.
- The Agent tool itself — no research/plan/implement dispatch under any circumstance.

**Practical implication**: the safest implementation shape is a NEW pure-bash/jq script (e.g.
`orchestrate-dry-run-report.sh`, to live alongside `orchestrate-batch-admit.sh` and be
registered in `manifest.json`'s `provides.scripts`, matching task 900's precedent) that
internally calls `orchestrate-batch-admit.sh` and `task-lock.sh check`, computes the wave
assignment using the same Kahn's-algorithm logic `orchestrate.md` Steps 2-3 already specify, and
reads `.orchestrator-handoff.json` per `partial`-status candidate for the triage classification
— never invoking `skill-base.sh`'s write-side functions, never calling `acquire`, never touching
`update-task-status.sh` or `generate-todo.sh`. `commands/orchestrate.md` and
`skills/skill-orchestrate/SKILL.md` (the "one code path, two consumers" requirement) should both
call this SAME script for their respective wave-split/eligibility checks (or continue calling
`orchestrate-batch-admit.sh` directly for the pure collision part, with the new script composing
it) rather than each independently re-deriving triage logic inline — this is the direct
analogue of how task 900 already unified the two previously-separate inline collision checks
into one shared script.

### Report Format Recommendations (from the "Verify Before Designing" framing + web research)

The task explicitly asks for: (1) the admitted set with wave assignment, (2) every excluded
candidate with a specific reason naming the colliding task/path or blocker, (3) a recommended
split when the admitted set should not run as one batch. Recommend structuring the printed
report so that:

- The excluded-candidates section is **never omitted or collapsed** even when empty — print an
  explicit "0 excluded" line rather than omitting the section, so a reader cannot mistake "the
  report didn't check" for "nothing was excluded." (See External Resources below — this
  is the single most load-bearing lesson from the approval-fatigue literature.)
- Each exclusion reason names the SAME structured fields `orchestrate-batch-admit.sh` and
  `task-lock.sh check` already emit (colliding task number + overlapping path; holder session +
  heartbeat age; predecessor task number + status; handoff staleness/blocker detail) rather than
  free-form prose, so the report is trivially diffable across repeated dry-runs of a changing
  batch — matching this codebase's existing preference for structured, machine-templated
  `reason` strings over prose (see `batch-admit-schema.md`'s own `reason` field convention).
- The "recommended split" surfaces the SAME wave numbers the live dispatch would use (not a
  separately-computed suggestion), so a human comparing the dry-run's split recommendation
  against the eventual live commit's wave-by-wave log sees the identical numbers — this is the
  "one code path, two consumers" requirement applied to the human-facing surface, not just the
  machine-facing one.

## External Resources

Web research current as of July 2026 on dry-run/plan-preview trust and the "always green"
failure mode:

- **Approval fatigue is a volume/attention problem, not a rigor problem**: "When every action
  surfaces an approval prompt, reviewers stop reading them and start rubber-stamping. Approval
  fatigue is a predictable consequence of how human attention works under repetitive load —
  volume overwhelms judgment." The practical industry response in 2026 is tiered approval
  postures (autonomous / async-notify / inline-approve / multi-party) rather than a single
  approve-everything gate, and — where full autonomy is used — moving the human review point to
  a single consolidated diff/PR rather than every intermediate step. This maps directly onto
  this codebase's existing design: `/orchestrate`'s human review point is the final consolidated
  batch commit and output table, not a per-cycle gate — `--dry-run` should be read as an
  *additional*, opt-in preflight surface for a human who wants to inspect batch composition
  before committing to a run, not a new synchronous gate inserted into the autonomous loop
  itself (consistent with `batch-orchestration-guardrails.md`'s explicit statement that no
  synchronous batch-approval gate exists in this system by design).
- **A green result communicates only "ran without crashing," not "did the right thing"**: from
  the Terraform/IaC plan-preview literature, "a green plan tells me that syntax is valid and
  providers are reachable — but it says nothing about whether I am about to merge a security
  misconfiguration... or miss an architectural concern." The direct analogue here: an
  admission report showing "8/8 admitted, 0 excluded" is meaningfully different information from
  "8/8 admitted because the analysis ran cleanly" vs. "8/8 admitted because the analysis
  degraded and skipped checking" (the `orchestrate-batch-admit.sh` exit-2 degradation path,
  already documented in `orchestrate.md` Step 3, is exactly this ambiguity) — the report must
  distinguish these, e.g. by explicitly stating which checks ran and which were skipped due to
  degraded state, never silently presenting a degraded run's output as equivalent to a clean one.
- **The concrete mitigation pattern from CI/CD tooling**: reduce noise so reviewers focus on
  what's risky (surfacing destroys/replaces/drift prominently rather than uniformly), and confirm
  actual effects rather than asserting them from an exit code alone ("downstream steps should
  confirm tags exist or diffs contain expected files rather than just asserting effect over exit
  codes"). Applied here: the dry-run's wave/exclusion computation should be asserted against the
  SAME underlying data structures the live dispatch reads (state.json, `.orchestrator-handoff.json`,
  lock state) — never a separately-maintained approximation — precisely the "one code path, two
  consumers" requirement the task description states directly.
- **A tiered/graduated signal beats binary pass/fail**: one source explicitly recommends a
  three-state visual distinction (e.g. high-confidence-green vs. uncertain-yellow) rather than a
  single boolean, prompting closer review exactly when confidence is lower. Applied here: a
  `held-stale` lock (informational, would not actually block the live `acquire`) should be
  visually/textually distinguishable in the report from a `held-fresh` lock (would actually
  block) — collapsing both into one "excluded: lock held" bucket loses exactly the distinction
  that makes the report worth reading closely.

Sources:
- [Agentic AI Approval Gates: A CISO Framework](https://www.thoughtwavesoft.com/insights/ciso-agentic-approval-gates-framework)
- [AI Agent Approval Layer Guide (June 2026) - Velt](https://velt.dev/blog/why-ai-agents-need-approval-layer)
- [Approval Fatigue Is Breaking AI Agents. Execution Boundaries Fix It.](https://medium.com/@shreya_edulakanti/approval-fatigue-is-breaking-ai-agents-execution-boundaries-fix-it-6c46c6d512dd)
- [Approval Fatigue - Encyclopedia of Agentic Coding Patterns](https://aipatternbook.com/approval-fatigue)
- [Human-in-the-Loop AI Agents: When Approvals Matter in 2026 | getclaw](https://getclaw.sh/blog/human-in-the-loop-ai-agents-approvals-2026)
- [How to Preview Infrastructure Changes with terraform plan](https://oneuptime.com/blog/post/2026-02-23-how-to-preview-infrastructure-changes-with-terraform-plan/view)
- [Building a DevSecOps Terraform Review Loop with Checkov, Infracost, and AI](https://dev.to/jackyho/building-a-devsecops-terraform-review-loop-with-checkov-infracost-and-ai-35h2)
- [Green CI Checks Don't Mean Working Software](https://earezki.com/ai-news/2026-07-13-green-ci-working-software/)
- [Green Checkmarks, Red Flags: What CI/CD Can't Catch | Conf42](https://www.conf42.com/DevOps_2026_Tilda_Udufo_cicd_quality_testing)
- [Designing For Agentic AI: Practical UX Patterns For Control, Consent, And Accountability — Smashing Magazine](https://www.smashingmagazine.com/2026/02/designing-agentic-ai-practical-ux-patterns/)

## Decisions

- The file-scope-collision portion of the admission analysis should be sourced directly from
  `orchestrate-batch-admit.sh` (task 900) with no reimplementation — it is already read-only and
  already the canonical predicate.
- The lock-held check must use `task-lock.sh check`, never `acquire`; the dry-run must compare
  the reported holder `session=` against the current session before treating a held-fresh lock
  as an exclusion (to avoid false-positive self-collisions), and must treat `held-stale`
  distinctly from `held-fresh` since only the latter would actually block a live `acquire`.
- The wave assignment printed by `--dry-run` must be produced by the identical Kahn's-algorithm
  computation `orchestrate.md` Steps 2-3 already specify (intra-batch dependency edges only),
  not a separate approximation, so the report cannot drift from the live wave order.
- `DRY_RUN_FLAG` should be added to `parse-command-args.sh` following the exact pattern of
  `CLEAN_FLAG`/`FORCE_FLAG` (init, regex scan, sed-strip, export) rather than parsed ad hoc
  inside `orchestrate.md`.
- Any new script this task introduces should be registered in `manifest.json`'s
  `provides.scripts`, matching task 900's precedent.

## Risks & Mitigations

- **Risk**: the classifier's handoff-triage precedence disagrees with whichever code path
  actually executes for a given argument count (single-task Stage 4 vs. multi-task Stage MT-4),
  producing a "confidently wrong" report for single-task `--dry-run` invocations specifically.
  **Mitigation**: resolve explicitly at plan time using Option (A) or (B) above; do not let the
  classifier silently default to MT-4 semantics for all invocation shapes.
- **Risk**: Stage MT-4's "partial with blockers -> failed_tasks (mark blocked)" row has no
  spelled-out pre-dispatch mechanism in the current SKILL.md (unlike the single-task path, which
  reads `blockers`/`continuation` explicitly before choosing a sub-state) — implementing the
  dry-run classifier might therefore require adding that missing mechanism to MT-4 itself (a
  shared file this task already touches) rather than only adding a parallel read inside the
  new dry-run script, since the task requires "one code path, two consumers," not two
  independently-verified implementations of the same rule.
  **Mitigation**: extract the triage precedence into one function/script both the live MT-4
  dispatch-composition step and the dry-run report call, mirroring how task 900 extracted the
  collision check into `orchestrate-batch-admit.sh` for both call sites.
- **Risk**: reading `.orchestrator-handoff.json` for every `partial`-status candidate in a large
  batch is still bounded (~400 tokens each per the schema's token budget) but is N reads instead
  of the collision script's single `state.json` read — for a `MAX_TASKS=8` batch this is at most
  8 small reads, well within budget, but should not be allowed to grow past the existing
  `MAX_TASKS` guard already enforced in `orchestrate.md`.
  **Mitigation**: reuse the existing `MAX_TASKS=8` guard for `--dry-run` too; do not introduce a
  separate, larger limit for preview-only invocations.
- **Risk (from web research)**: an admission report that is well-designed but always shows a
  clean batch trains its human reader to stop reading it (the "always green" failure mode), just
  as thoroughly as a genuinely uninformative report would.
  **Mitigation**: always print the exclusion section explicitly (never omit when empty), and
  distinguish "checks ran cleanly" from "checks were skipped due to degraded state" (the
  `orchestrate-batch-admit.sh` exit-2 path) in the report's own text, per the Report Format
  Recommendations above.

## Context Extension Recommendations

- **Topic**: MT-4 phase-grouping table's pre-dispatch blocker-classification mechanism.
  **Gap**: `skill-orchestrate/SKILL.md` Stage MT-4's table asserts a "partial with blockers ->
  failed_tasks (mark blocked)" outcome, but no literal code block in Stage MT-3/MT-4 shows how
  `blockers`/`continuation` are read from each partial task's handoff BEFORE dispatch
  composition (unlike the single-task Stage 4 handler, which shows this explicitly). Whichever
  task implements this dry-run classifier will likely need to add that missing mechanism.
  **Recommendation**: once implemented, `orchestrate-state-machine.md`'s "MT Mode" section should
  gain an explicit code/pseudocode block analogous to the single-task Stage 4 handler's
  `continuation=$(...); blocker_count=$(...)` reads, so the MT-4 table's third row stops relying
  on inference from a table alone.

## Appendix

### Search Queries Used
- "2026 autonomous agent dry-run plan preview trustworthy approval fatigue rubber stamp always green"
- "infrastructure as code plan preview terraform \"always green\" reviewers stop reading approval fatigue"
- "designing trustworthy CI plan preview report surface exceptions not just green checkmark 2026"

### Key Files Referenced (agent-system/extensions/core/ — the source store; .claude/ is the
disposable deploy artifact and is never edited directly)
- `scripts/orchestrate-batch-admit.sh`, `docs/architecture/batch-admit-schema.md`
- `scripts/task-lock.sh`, `context/patterns/task-lock.md`
- `scripts/parse-command-args.sh`
- `commands/orchestrate.md` (Steps 1-3, Stage 0, CHECKPOINT 1/STAGE 2)
- `skills/skill-orchestrate/SKILL.md` (Stage 4 partial-substate handler, lines ~359-416; Stage
  MT-3/MT-4, lines ~926-1145)
- `docs/architecture/orchestrate-state-machine.md` (Complete State Table, MT Mode section)
- `docs/architecture/handoff-schema.md` (Reading Contract, token budget)
- `context/patterns/batch-orchestration-guardrails.md` (blocking-vs-advisory criterion,
  knowability test, Non-Negotiables, Open Design Fork)
- `context/patterns/file-footprint-overlap.md`
- `specs/900_cross_batch_file_scope_admission/` plan, summary, and test suite (precedent for
  script structure, manifest registration, and test conventions)
