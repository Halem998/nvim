# Research Report: Build orchestrate-cycle-plan.sh

- **Task**: 147 - Build orchestrate-cycle-plan.sh: one script that returns the cycle's whole dispatch plan
- **Started**: 2026-09-02T00:00:00Z
- **Completed**: 2026-09-03T00:00:00Z
- **Effort**: large (single script absorbing ~35 KB of SKILL.md prose/bash)
- **Dependencies**: 146 (`orchestrate-build-dispatch.sh`, landed — this script's dispatch-file
  builder dependency)
- **Sources/Inputs**: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage
  MT-1 through MT-4), `scripts/orchestrate-batch-admit.sh`, `scripts/orchestrate-triage-classify.sh`,
  `scripts/orchestrate-build-dispatch.sh`, `scripts/orchestrate-stage5-gates.sh`,
  `scripts/orchestrate-stage5-postflight.sh`, `scripts/orchestrate-dry-run-report.sh`,
  `scripts/command-route-agent.sh`, `scripts/lib/manifest-routing-lib.sh`, `scripts/task-lock.sh`,
  `scripts/skill-base.sh` (`skill_preflight_update`), `context/reference/orchestrator-critical-paths.json`,
  `commands/orchestrate.md`, `manifest.json`, `specs/PATH.md`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The new script absorbs **Stage MT-3 steps 1-4.5** (status refresh, heartbeat, all-terminal
  check, eligibility, classifier call, admission call + full verdict branching, convergence
  guard, redeploy checkpoint) and **Stage MT-4's pre-dispatch half** (dispatch-bucket grouping
  from classifier output, task-lock acquire with stale-reclaim, `dispatch_seq` mint, preflight
  status write, per-task `orchestrate-build-dispatch.sh` call) — everything up to, but not
  including, the Agent tool invocations and everything from "After all Agent tool calls complete"
  onward (that postflight half belongs to task 143's `orchestrate-cycle-postflight.sh`).
- Every downstream primitive the script needs already exists with a stable CLI/output contract:
  `orchestrate-batch-admit.sh` (verdict schema v5), `orchestrate-triage-classify.sh` (verdict
  schema v1), `orchestrate-build-dispatch.sh` (`{dispatch_file, model}`), and
  `command-route-agent.sh` (sourced, exports `AGENT_NAME`). The new script is glue, not a
  reimplementation of any of these.
- The compact-JSON scripting style to imitate is `orchestrate-stage5-gates.sh` /
  `orchestrate-stage5-postflight.sh`: a doc-header with Usage/Output/Exit-codes, positional args,
  one `jq -n -c` object on stdout, and — critically — the script performs real writes
  (status/lock/state) but never decides orchestrator LOOP CONTROL (that stays with the caller;
  here, the four-moves loop in the rewritten `SKILL.md`).
- The `mt_state_file` schema (Stage MT-1) is the persistent state this script reads and mutates
  every cycle; its ~15 fields (dispatch_seq_counter, dispatch_seq, dispatch_start_ts,
  deferred_self_modifying, defer_ledger, idle_overlap_ledger, deployed_critical_paths,
  deferred_deploy_checkpoint, consecutive_no_dispatch_cycles, infra_failures,
  descriptions, current_statuses, cycle_count, `verify_deploy_baseline_notices`,
  `detected_defects`) are fully specified in Stage MT-1 and must be preserved byte-identically —
  they are still read by Stage MT-5 (postflight/report), which is out of scope here.
- Retiring `orchestrate-dry-run-report.sh` is a **verbatim-relay fix**, not a new feature: the
  retired script currently reconstructs its own self-modification reason string
  (`"deferred out of this invocation — re-run it alone (orchestrator-critical work runs solo
  only, never alongside sibling tasks)"`) instead of relaying `orchestrate-batch-admit.sh`'s own
  `reason` field, which already names the designated candidate and states the one-cycle ordering
  constraint. The new script's `--dry-run` path must never reintroduce those two literal phrases.
- Per-task `force_phases` consumption and missing-task-directory creation are **genuinely new**
  logic (not extracted from existing SKILL.md prose) — multi-task mode today only emits an
  accepted-and-ignored diagnostic notice for `force_phases` (Stage MT-1) and has no directory
  auto-creation at all. Both must be authored from the single-task Stage 2b analogue and from
  `skill_validate_input`'s directory-creation precedent, not lifted from an existing MT block.

## Context & Scope

Task 147 is Stage A.3 of `specs/PATH.md`'s "thin lead" plan: replace ~35 KB of inline
`SKILL.md` bash/jq (Stage MT-3 steps 1-4.5, Stage MT-4's per-task pre-dispatch work) with one
script call, `orchestrate-cycle-plan.sh`, invoked once per cycle by the rewritten four-move
engine (task 88, downstream). This research scopes exactly what the script must read, call, and
emit; it does not design task 143's postflight script or task 88's engine rewrite, both of which
consume this script's output but are separately dispatched tasks.

The 2026-09-02 addendum folds in a second, previously separate task (141, now abandoned into
147): `orchestrate-dry-run-report.sh` is retired outright and its `--dry-run` capability becomes
a mode of this same script, so there is exactly one rendering of the admission verdict instead of
two independently-maintained ones. The addendum also withdraws the `team` field/flags — no team
research is needed.

## Findings

### Current architecture: what Stage MT-3/MT-4 do today (source of truth: SKILL.md)

**Stage MT-3 (`SKILL.md:2685-3132`), 7 numbered steps, run once per cycle inside `while
cycle_count < MAX_CYCLES_MT`:**

1. Status refresh (re-read each task's status into `mt_state_file.current_statuses`) + best-effort
   `task-lock.sh session-heartbeat "$session_id"`.
2. All-terminal check: if every task is in `{completed, abandoned, expanded}`, `failed_tasks`, or
   `deferred_deploy_checkpoint` — break (success/partial). `deferred_self_modifying` is
   deliberately NOT part of this check (it is an observation log, not an exclusion set).
3. Build `eligible_tasks`: NOT terminal/failed, NOT in `deferred_deploy_checkpoint`, all
   `dependency_graph[task]` predecessors terminal-or-failed. **Not status-gated** — a task's own
   status (including `researching`/`planning`) never removes it from eligibility; only locks,
   `dependencies[]`, and `file_scope` overlap do, downstream.
4. No-eligible circuit breaker: empty `eligible_tasks` + a non-terminal, non-failed,
   non-deferred-checkpoint task remaining -> log + break (partial).
5. Step 4.5 (the bulk of the file): classifier call
   (`orchestrate-triage-classify.sh mt "${eligible_tasks[@]}"`, captured as `$mt_classify_ndjson`
   and reused — never re-invoked — by Stage MT-4), build `--phase-map` from it, call
   `orchestrate-batch-admit.sh --invocation-count "${#eligible_tasks[@]}" --session-id
   "$session_id" --phase-map "$phase_map_arg" "${eligible_tasks[@]}"` **every cycle including
   batch size 1**, then branch on `.decision == "defer"` -> `defer_reason` in
   `{self_modifying, file_scope_collision, session_active}`, each with its own consumer-side
   override check (`allow_self_modifying`, `allow_scope_collision` — cross-batch only),
   defer-not-fail removal from the batch, and `defer_ledger`/`deferred_self_modifying` bookkeeping.
   Also: the idle-overlap advisory (v5, checked on every verdict independent of the defer filter),
   the convergence guard (`consecutive_no_dispatch_cycles`, break after 3), and the degradation
   path (exit 2 from admit -> proceed without the check, loud warning).
6. Dispatch (delegated to Stage MT-4).
7. Increment `cycle_count`; break if `>= MAX_CYCLES_MT`.
8. Inter-cycle redeploy checkpoint: expand `orchestrator-critical-paths.json` against
   `cycle_modified_files`, idempotence-guard against `deployed_critical_paths`, run
   `verify-deploy.sh` pre/post `deploy-headless.sh`, three-way outcome (success /
   pre-existing-failure-proceed / new-failure-defer), all logged via
   `mt_state_file.deferred_deploy_checkpoint` / `deployed_critical_paths` /
   `verify_deploy_baseline_notices`.

**Stage MT-4 pre-dispatch half (`SKILL.md:3133-3358`):** `jq`-filter the SAME captured
`$mt_classify_ndjson` (not re-invoked) into `research_tasks`/`plan_tasks`/`implement_tasks`
buckets (`.group` values); `needs_human`/`skip` handled per the Phase-grouping table. Then, per
task, before composing the single batched Agent-tool message: `task-lock.sh acquire "$task_num"
"$op" "$session_id" "..."` (defer-not-fail on refusal — a fresh foreign lock removes the task
from this cycle only, never adds to `failed_tasks`); mint `dispatch_seq` (an atomic
read-modify-write incrementing `mt_state_file.dispatch_seq_counter`, recording both
`dispatch_seq[$t]` and `dispatch_start_ts[$t]` in the SAME jq write); `skill_preflight_update
"$task_num" "$op" "${session_id}_${task_num}"` (note: implement uses the BARE `$session_id`, not
the per-task-suffixed form — see Invariant below); then `orchestrate-build-dispatch.sh
"$task_num" "$phase" --session ... --seq ... --dispatch-start-ts ... [--clean] [--lit] [--hard]
[--fast] [--model M]`, capturing `{dispatch_file, model}`.

**Session-id invariant (load-bearing, easy to get wrong):** the bare `$session_id` (not
`${session_id}_${task_num}`) MUST be used for `task-lock.sh acquire`, `orchestrate-batch-admit.sh
--session-id`, and the implement-loop's `orchestrate-build-dispatch.sh --session`/agent `context.
session_id`, because `session_contention()`'s self-exclusion and
`general-implementation-agent`'s per-phase `task-lock.sh heartbeat` both do exact string matches
against this value. The per-task-suffixed form (`${session_id}_${task_num}`) is used ONLY for
`skill_preflight_update`'s session argument and for the research/plan loops'
`orchestrate-build-dispatch.sh --session` argument and their agent `context.session_id` — i.e.
research/plan dispatches use the suffixed form, implement dispatches and the lock/admission calls
use the bare form. Getting this backwards desyncs the heartbeat from the acquired lock or makes
the batch's own session registration read as foreign to itself.

### Downstream script contracts (stable; build on these, do not reimplement)

**`orchestrate-batch-admit.sh`** — `--invocation-count N --session-id ID --phase-map "t:g,..."
task_num [task_num...]`, NDJSON on stdout, schema `orchestrate-batch-admit-v5`. Fields per
verdict: `$schema, task_number, decision (admit|defer), self_modifying (bool|null),
defer_reason (self_modifying|file_scope_collision|session_active), critical_path,
critical_label, colliding_task_number, colliding_task_status, overlapping_path,
collision_scope (in_batch|cross_batch), corroborated_by[], session_id,
session_liveness_reason, reason, idle_overlap_advisory{...}`. Exit 0 always emits verdicts
(defer is data, not an error); exit 2 = state unavailable (missing jq / unreadable state.json) —
caller must log loudly and proceed WITHOUT the check, never abort. The designated-candidate
tie-breaker (lowest task number among self-modifying candidates admits solo every cycle) is
internal to this script — the caller passes nothing extra for it.

**`orchestrate-triage-classify.sh`** — `<engine: single|mt> task_num [task_num...]`, NDJSON,
schema `orchestrate-triage-v1`. Fields: `$schema, task_number, engine, status, group (research|
plan|implement|needs_human|skip|terminal|exit_partial), handoff_state, blocker_count,
handoff_age_min, reason`. Exit 2 on usage error or unavailable state (nothing on stdout in that
case — the new script's degradation path per SKILL.md is to fall back to the Phase-grouping table
applied inline per task, not to abort the cycle).

**`orchestrate-build-dispatch.sh`** — `<task_number> <phase> --session SID --seq N
[--clean] [--lit] [--hard] [--fast] [--model M] [--focus] [--territory] [--dispatch-start-ts TS]`.
`--seq`/`--dispatch-start-ts` are caller-minted, never generated inside this script. Prints
`{"dispatch_file": "<abs path>", "model": "<haiku|sonnet|opus|fable|>"}`. Exit 1 = task not
found/terminal; exit 2 = usage error.

**`command-route-agent.sh`** — must be **sourced**, not executed as a subprocess:
`source .claude/scripts/command-route-agent.sh "$op" "$TASK_TYPE" "$default_agent"
"${effort_flag:-}"` then read `$AGENT_NAME`. It never calls `exit`. This resolves the per-task
`agent` field the new script's dispatch rows require — today this resolution lives in Stage MT-2
(run once per invocation, before the cycle loop, populating `mt_state_file.research_agents` /
`implement_agents` maps), which is **out of scope** for this dispatch (not named in the WORK
section). Two workable designs: (a) the new script re-sources `command-route-agent.sh` itself,
per admitted task, per cycle (cheap — a few jq/case lookups, no filesystem walk) rather than
depending on MT-2's precomputed maps, which keeps the script self-contained and matches the
"reuse manifest-routing-lib.sh and command-route-agent.sh" design constraint literally; or (b)
the script accepts `research_agents`/`implement_agents` as already-resolved input (e.g. read from
`mt_state_file`, which MT-2 still populates). (a) is recommended: it removes a hidden
dependency on MT-2 running first in exactly the shape it does today, and the resolution itself is
cheap and side-effect-free.

**Compact-JSON scripting pattern to imitate** (`orchestrate-stage5-gates.sh`,
`orchestrate-stage5-postflight.sh`): doc header (Purpose / Usage / Output field table / Exit
codes), positional (not flag-heavy, except where flags are genuinely optional) arguments, `set
-euo pipefail`, one `jq -n -c '{...}'` object on stdout as the sole return channel, and the
explicit split of responsibility — **the script performs real writes** (state.json,
`.lock/`, status transitions) **but never decides loop control** (halt/continue,
`cycle_count` increment) — that stays with the caller. `orchestrate-cycle-plan.sh` should follow
this exactly: it performs the real writes (status refresh via re-read, lock acquire,
`dispatch_seq` mint, preflight status write, `mt_state_file` mutations for defer/observation
logs) but the caller (the rewritten `SKILL.md` loop, task 88) still owns deciding whether the
returned `stop` object ends the invocation.

### `mt_state_file` schema (Stage MT-1) — persistent contract this script reads/writes

Initialized once by Stage MT-1 (out of scope — a separate, still-live stage) at
`specs/.orchestrator-multi-state-${session_id}.json`. Fields the new script must read and/or
mutate every cycle: `session_id, task_numbers, waves (diagnostic only, never consumed),
max_cycles, cycle_count, failed_tasks[], completed_tasks[], current_statuses{},
task_dirs{}, research_agents{}, implement_agents{}, descriptions{}, infra_failures{},
dispatch_start_ts{}, dispatch_seq_counter, dispatch_seq{}, deferred_self_modifying[]
(append-only observation log, NOT an exclusion set), deferred_deploy_checkpoint[] (genuine
permanent-for-invocation exclusion), deployed_critical_paths[], consecutive_no_dispatch_cycles,
verify_deploy_baseline_notices[], defer_ledger[], detected_defects[],
forward_progress_violated (Stage MT-5 only — do not touch here), idle_overlap_ledger[]`. All the
observation logs (`defer_ledger`, `detected_defects`, `idle_overlap_ledger`,
`verify_deploy_baseline_notices`) share one MUST NOT: never read by any eligibility/admission/
circuit-breaker/convergence decision — they exist solely for Stage MT-5's reporting, which is
out of scope here but the new script must keep appending to them exactly as today so that stage
still renders correctly.

### `--dry-run` retirement of `orchestrate-dry-run-report.sh`

The retired script currently (1) re-implements batch validation and a Kahn's-algorithm wave
split the live path no longer computes (Stage MT-3 step 4.5 re-derives eligibility fresh every
cycle instead of a precomputed wave schedule) — this reimplementation is exactly the "two
renderings that drift apart" the addendum names; (2) calls `orchestrate-batch-admit.sh` ONCE
with `--invocation-count` set to the **whole validated set's size**, not a per-cycle co-dispatch
count — mismatched with the live path's per-cycle `${#eligible_tasks[@]}`; and (3) on a
self-modifying defer, prints its OWN hardcoded reason line (`"deferred out of this invocation —
re-run it alone (orchestrator-critical work runs solo only, never alongside sibling tasks)"`)
instead of the verdict's own `reason` field. The verification bar named in the addendum
(inherited from the abandoned task 141) requires the new script's `--dry-run` mode to relay the
admission verdict's `reason` string **verbatim** for every defer row, and forbids the two
phrases `"runs solo only"` and `"re-run it alone"` from appearing anywhere in the new script —
both are grep-checkable literal strings unique to the old script's hardcoded text (confirmed:
`grep -rn "runs solo only|re-run it alone"` across the source store matches only
`orchestrate-dry-run-report.sh` today).

Because `--dry-run` is now "the identical read-only analysis... plus a compact human table
derived from that JSON object and nothing else," the cleanest implementation is: the script's
normal (non-dry-run) code path already produces the full plan JSON object as an intermediate
value before it would start dispatching; `--dry-run` short-circuits immediately after that JSON
is assembled — skipping lock acquire, `dispatch_seq` mint, preflight status write, task-dir
creation, and the `orchestrate-build-dispatch.sh` calls entirely (per the dry-run prohibition
block: "a dry run dispatches nothing, mutates nothing, acquires no lock") — and renders the human
table purely from that JSON, never from a second independent computation. This means `--dry-run`
cannot simply be "skip printing the table" on the live path; the live path's plan JSON's
`dispatch[]` rows need `dispatch_file`/`model` populated (which requires the build-dispatch call
and, transitively, the lock+mint+preflight sequence), while dry-run's rows must NOT have any of
those side effects. The two paths therefore diverge exactly at "would call
`orchestrate-build-dispatch.sh` and everything upstream of it (lock, mint, preflight write, dir
creation)" — dry-run stops one step earlier, after admission+classification+force-phase
resolution are known, and renders dispatch rows with `dispatch_file`/`model` omitted or null,
still carrying `task`/`phase`/`agent` so the human table is informative.

Retirement mechanics found:
- `manifest.json` lists `orchestrate-dry-run-report.sh` once under `scripts` (line 134,
  alphabetically between `orchestrate-build-dispatch.sh` and `orchestrate-predispatch-review.sh`)
  — add `orchestrate-cycle-plan.sh` in its place (alphabetical slot is before
  `orchestrate-dry-run-report.sh`, i.e. between `build-dispatch.sh` and `loop-guard-init.sh` once
  the old entry is removed). No test manifest entry exists for the old script to remove (it has
  no dedicated `tests/test-orchestrate-dry-run-report.sh` — confirmed via search; only
  `test-orchestrate-build-dispatch.sh` and `test-orchestrate-triage-classify.sh` exist as
  siblings). A new `tests/test-orchestrate-cycle-plan.sh` should be added to `manifest.json`
  following those two files' naming/placement convention.
- `context/reference/orchestrator-critical-paths.json` lists `scripts/orchestrate-dry-run-report.sh`
  (label: "admission report surface") among 13 declared critical paths (this file is itself
  self-referential with `recursion_guard: true` on its own entry and on
  `system-defect-discrimination.md`). Remove that entry; add
  `scripts/orchestrate-cycle-plan.sh` in its place, labeled something like "cycle dispatch-plan
  composer (admission + classification + dispatch orchestration)" — it inherits the "admission
  report surface" role and gains far more (lock acquire, status writes, dispatch-seq mint), so it
  is unambiguously still an orchestrator-critical path requiring the self-modification gate.
- `commands/orchestrate.md`'s dry-run short-circuit (lines ~93-101) currently calls
  `orchestrate-dry-run-report.sh [--session SID] $TASK_NUMBERS` unconditionally before the
  `len(TASK_NUMBERS)` branch (i.e. dry-run works for single-task invocations too, not just
  multi-task). Repoint to `orchestrate-cycle-plan.sh --dry-run --session SID
  --state-file specs/state.json $TASK_NUMBERS` (exact flag shape TBD by the plan, but the call
  site is a single one-line substitution). The surrounding prohibition block ("MUST NOT continue
  to multi-task dispatch... MUST NOT acquire a task lock... MUST NOT run CHECKPOINT 3") is
  unchanged prose and does not need editing beyond the script name.
- No other file references `orchestrate-dry-run-report.sh` as an executable call site outside
  itself, `manifest.json`, and `commands/orchestrate.md`. Several context/docs files
  (`batch-orchestration-guardrails.md`, `file-footprint-overlap.md`, `task-lock.md`,
  `batch-admit-schema.md`, `context/reference/README.md`) mention it descriptively — these are
  documentation cross-references, not code changes, but a thorough pass should rename them to
  `orchestrate-cycle-plan.sh --dry-run` for accuracy (not verified individually here; flagged for
  the plan/implementation phase to grep-and-check at delete time).

### Genuinely new logic (not extractable from existing SKILL.md prose)

1. **Per-task `force_phases` consumption.** Today, Stage MT-1 only emits a diagnostic notice
   ("accepted and ignored in multi-task mode") and never builds a per-task force queue. The
   single-task analogue (Stage 2b, `SKILL.md:477-588`) is the model to port: split
   `force_phases` on commas into an ordered queue validated against `{research, plan, implement}`
   (fail loudly on anything else — a corrupted delegation context, not a user typo), track a
   per-task "remaining forced phases" pointer, and honor "canonical ordering and
   stop-after-last-named semantics" — i.e. forced phases always run in
   research-then-plan-then-implement order regardless of the flags' typed order (already true of
   `parse-command-args.sh`'s accumulation, per Stage 2b's own comment), and once the last named
   forced phase for a task completes, that task stops being force-dispatched and falls through to
   ordinary status-derived classification on the next cycle (mirroring `/orchestrate`'s
   documented single-task semantics in CLAUDE.md: "stopping after the last named phase rather
   than falling through to status-derived dispatch" — for multi-task this becomes *per task*
   rather than a single global stop). This is multi-task's genuine feature gap, not a code
   relocation.
2. **Missing task-directory creation.** No existing MT stage creates `specs/{NNN}_{slug}/` when
   `state.json` has `path: null` or the directory is absent — this is the "multi-task missing-
   directory gap" the dispatch names explicitly. The single-task engine's directory-creation
   precedent lives in `skill_validate_input`/`skill-base.sh` (mkdir -p semantics on first dispatch
   for a fresh task); the new script should call the same shared helper (or replicate its
   `mkdir -p` + `path` field write) per admitted task before calling
   `orchestrate-build-dispatch.sh`, since that script's own doc header states it "re-derives this
   task's description directly from `specs/state.json`" and would fail if the directory does not
   yet exist. This ordering (create dir -> build dispatch) matters and should be made explicit in
   the plan.

### Test precedents to model fixture tests after

`tests/test-orchestrate-build-dispatch.sh` and `tests/test-orchestrate-triage-classify.sh` are
the two existing sibling test files (both in `manifest.json`'s `tests/` list, alongside
`tests/run-all.sh`). The acceptance criteria's four fixture areas map directly onto the
downstream contracts already covered above:
- **Eligibility**: exercise Stage MT-3 step 3's rule (status-not-gated; dependency-graph
  predecessor terminal-or-failed) against a small fixture `state.json`.
- **Per-task forced phases**: exercise the new force-queue logic (item 1 above) — a fixture
  with `--force-phases "research,plan"` for one task among several, verifying only that task's
  named phases are forced and it falls through afterward.
- **Verdict relay**: assert the `--dry-run` human table's rendered defer reason is
  byte-identical (modulo formatting) to `orchestrate-batch-admit.sh`'s own `.reason` field for a
  fixture with 2+ self-modifying candidates — this is the addendum's explicit bar, and the
  negative assertion (`grep -v` for the two forbidden phrases) belongs in this same test.
- **Lock refusal removing a task from the batch**: fixture two tasks, pre-acquire a lock under a
  different session_id for one, assert it is absent from `dispatch[]` and present in `deferred[]`
  with a lock-contention reason, never in `blocked[]`.

## Decisions

- **Agent resolution belongs inside the new script** (design (a) above), sourcing
  `command-route-agent.sh` per admitted task per cycle, rather than depending on Stage MT-2's
  precomputed `research_agents{}`/`implement_agents{}` maps as an input — keeps the script
  self-contained and matches the literal "reuse... command-route-agent.sh" design constraint.
  (Recorded as a recommendation for the planning phase, not an irreversible commitment — MT-2
  itself is untouched by this task and could still be the source if the plan prefers threading
  the maps through instead.)
- **`--dry-run` and the live path share one JSON-assembly code path**, diverging only at the
  point where `orchestrate-build-dispatch.sh` (and its lock/mint/preflight-write prerequisites)
  would be called — `--dry-run` stops one step earlier and renders the human table from the same
  JSON object, per the addendum's "one rendering... instead of two."

## Recommendations

1. Author `scripts/orchestrate-cycle-plan.sh` following the `orchestrate-stage5-*.sh` doc-header
   and single-`jq -n -c`-object-on-stdout convention; keep loop-control decisions (whether `stop`
   is non-null) as data in the returned JSON, never as an `exit` code side effect the caller must
   interpret beyond "0 = plan printed."
2. Sequence the implementation in the same order Stage MT-3/MT-4 already run today (status
   refresh -> all-terminal -> eligibility -> classify -> admit+branch -> force-phase resolution
   -> directory creation -> lock+mint+preflight -> build-dispatch per admitted task -> budget/
   redeploy-checkpoint accounting), since every later step's precondition already assumes the
   earlier ones ran this cycle.
3. Grep the context/docs files listed above for `orchestrate-dry-run-report.sh` mentions at
   delete time and update them to `orchestrate-cycle-plan.sh --dry-run` for accuracy, even though
   they are not code call sites.
4. Write the fixture tests (eligibility, forced phases, verdict relay, lock refusal) as a single
   `tests/test-orchestrate-cycle-plan.sh`, added to `manifest.json` immediately after
   `tests/test-orchestrate-build-dispatch.sh`/`tests/test-orchestrate-triage-classify.sh`.
5. The plan phase should explicitly decide the exact flag surface for `--dry-run` (this research
   found the addendum's *behavioral* requirements but not a prescribed flag name beyond
   `--dry-run` itself) and the precise human-table column layout, since the addendum only
   requires it be "derived from that JSON object and nothing else," not a specific format.

## Risks & Mitigations

- **Risk**: implementing agent-resolution via a fresh `command-route-agent.sh` source per task
  per cycle silently diverges from Stage MT-2's existing per-invocation resolution if an
  extension's manifest routing changes mid-invocation (unlikely but possible if `--hard` state
  differs). **Mitigation**: resolve once per task the first cycle it becomes eligible and cache
  in `mt_state_file`, mirroring MT-2's once-per-task intent, rather than re-resolving every
  cycle — cheap either way, but caching avoids any theoretical drift.
- **Risk**: the `--dry-run`/live-path shared-JSON design could tempt an implementer into
  duplicating the admission+classification computation for the two modes if not careful about
  where the fork point is. **Mitigation**: structure the script as one function producing the
  full decision set (admit/defer/classify/force-phase-resolve) and a second, later function that
  either renders the human table (dry-run) or proceeds to write side effects and call
  `orchestrate-build-dispatch.sh` (live) — never two separate code paths computing decisions.
- **Risk**: forgetting the bare-vs-suffixed `session_id` invariant (documented above) when
  porting the per-task loops would desync `task-lock.sh heartbeat` from the acquired lock for
  implement dispatches, or make the batch's own session registration look foreign to itself.
  **Mitigation**: call this out explicitly as a named invariant/test assertion in the
  implementation plan, not just prose.

## Context Extension Recommendations

- **Topic**: `orchestrate-cycle-plan.sh`'s own future doc-header should become the durable
  source for the mt_state_file field list and the bare-vs-suffixed session_id invariant, both of
  which currently exist only as prose scattered across `SKILL.md`. No new context file is needed
  now (the script's own header comment, following the established convention, is where task 88's
  later `docs/architecture/orchestrate-state-machine.md` relocation should point).

## Appendix

- Key files read: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (Stage
  MT-1 through MT-4, lines 2418-3506), `scripts/orchestrate-batch-admit.sh` (full doc header),
  `scripts/orchestrate-triage-classify.sh` (doc header + output schema),
  `scripts/orchestrate-build-dispatch.sh` (full, 355 lines), `scripts/orchestrate-stage5-gates.sh`
  and `scripts/orchestrate-stage5-postflight.sh` (doc headers), `scripts/orchestrate-dry-run-report.sh`
  (doc header + grep for retirement strings), `scripts/command-route-agent.sh` (doc header),
  `context/reference/orchestrator-critical-paths.json` (full, 70 lines), `manifest.json`
  (scripts/tests listing), `commands/orchestrate.md` (dry-run short-circuit block), `specs/PATH.md`
  (Stage A.3 description and Target Design section).
- Search commands used: `grep -rn "runs solo only|re-run it alone"`,
  `grep -rln "orchestrate-dry-run-report" .`, `find . -iname "*dry-run*"`,
  `grep -n "command-route-agent.sh|routing_lookup|research_agents\[|implement_agents\[" SKILL.md`.
