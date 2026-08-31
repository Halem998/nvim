# Research Report: Task #119

**Task**: 119 - Migrate hard mode state machine logic
**Started**: 2026-08-31T00:00:00Z
**Completed**: 2026-08-31T22:52:00Z
**Effort**: general (meta)
**Dependencies**: Task 117 (completed), Task 118 (completed)
**Sources/Inputs**: - Codebase (agent-system/extensions/core/skills/skill-orchestrate/SKILL.md, agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md), specs/116_core_agent_system_consolidation/reports/03_target-state-design.md, specs/TODO.md
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both prerequisite tasks (117: dispatch-prep stage, 118: `hard_contracts` text injection) are
  landed. `skill-orchestrate/SKILL.md` already derives a `hard_mode` boolean at Stage 1 (and
  Stage MT-1 for multi-task), already resolves `RESEARCH_AGENT`/`PLANNER_AGENT`/`IMPLEMENT_AGENT`
  through the unified `command-route-agent.sh` ladder (Stage 1b — no separate work needed there),
  already runs Stage 3.5 Dispatch Prep's `hard_contracts_block` contract-TEXT injection, and
  already carries a base-mode `budget-continuation-override` twin of hard mode's Stage 2 region.
  Four items remain genuinely unmigrated and are exactly the task's WORK list.
- The four migration targets, with exact source line ranges in
  `skill-orchestrate-hard/SKILL.md` (1,823 lines total) as of this research pass:
  1. **Loop-guard/churn-state init** — the `loop-guard-staleness` 3-signal detector (lines
     249-317), the `churn_file` init block (lines 425-447), and two new guard-JSON fields
     (`hard_mode: true`, `burnout_signals_this_session: 0`) inside the existing fresh-init/resume
     blocks (lines ~319-443) — insert into base Stage 2 (currently lines 103-272).
  2. **Burnout circuit-breaker gate** — Stage 3c (lines 544-581) — insert into base Stage 3
     between "3b. Update loop guard" and "3c. Dispatch by state" (base currently lines ~310-320).
  3. **Churn detection (H6) + three-strikes audit dispatch (H5)** — Stage 4b (lines 1080-1134) —
     runs after every implement dispatch returns, before/alongside base Stage 5 Handoff Reading.
  4. **H1 per-phase dispatch limiter** — the `#### State: planned or implementing — Per-Phase
     Dispatch (H1)` handler (lines 747-966) — replaces/branches around base's whole-plan dispatch
     handler (base currently lines 676-701).
- `MAX_CYCLES` must become conditional: `5` in base mode (current, line 115), `13` in hard mode
  (current, line 229) — a one-line `if $hard_mode` branch at the top of Stage 2, not a
  structural change.
- The H1 handler is the largest migration surface (~220 lines) but most of its bulk (heading-scan
  phase selection, marker/handoff crosscheck, skeleton-exhaustion routing, territory-key
  construction) is *already* phase-aware machinery mirrored from
  `general-implementation-hard-agent.md` Stage 3b — it is copy-adapt work, not new design. The
  genuinely hard-mode-specific delta against base's existing whole-plan handler is: (a) scan for
  the next OPEN phase heading instead of dispatching the whole plan, (b) build a `phase_number` +
  `territory` key into `dispatch_context`, (c) use `build_hard_mode_prompt_context()`'s phase-only
  mission framing, (d) route skeleton-exhaustion via the `pr_ready` postflight path.
- Recommended structure: wrap each of the four migration sites in `if [ "$hard_mode" = "true" ];
  then ... else ... fi` (or a single early branch for #4, since the two handler bodies are
  structurally different implementations of the same state, not decorated variants of one body).
  This mirrors the file's existing pattern for the already-migrated `budget-continuation-override`
  region, which is a bare shared block (not gated) because it is identical in both modes — the
  four items below are NOT identical in both modes, so each needs its own `if $hard_mode` fork
  rather than a shared block.

## Context & Scope

Task 119 migrates the last category of hard-mode residue identified by the A4 design decision in
`specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`: **stateful
counters and thresholds** that cannot be expressed as prompt-injected contract text (that part —
H2/H3/H4/H7/H9-shaped contract references — was task 118's scope and is done). This report
verifies the current state of both files against the design report's line-count estimates (which
were measured before tasks 117/118 landed and therefore predate the current, larger
`skill-orchestrate/SKILL.md`) and pins down exact current line ranges and insertion points for a
subsequent `/plan`.

**Out of scope for this task** (per its own WORK list and the sibling tasks' scope statements):
- Deleting `skill-orchestrate-hard/SKILL.md` itself and its sibling `-hard` files — task 121,
  which is explicitly gated on this task landing first (task 121's PRECONDITION: "the hard-mode
  contract-injection mechanism, the state-machine residue migration, and the test/lint
  retargeting must all already be landed").
- Retargeting the 7 test/lint files that assert against `skill-orchestrate-hard/SKILL.md`
  (`test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`,
  `test-handoff-reader-parity.sh`, `test-loop-guard-staleness.sh`,
  `test-handoff-dispatch-identity.sh`, `test-resume-scan-nonconformance.sh`,
  `lint-contract-compliance.sh`) — task 120, dependent on this task.
- Contract-TEXT injection (H2/H3/H4/H7/H9 references) — already done by task 118 inside Stage 3.5
  Dispatch Prep.
- Team/multi-task fanout changes — a separate task (122); hard mode's own `## Multi-Task Mode`
  section already states it delegates entirely to base's MT-1..MT-5 stages and needs no
  transcription of its own, so the single-task changes below automatically cover the multi-task
  wave path once base's single-task per-task dispatch is itself hard-mode-aware.

## Findings

### Current State of `skill-orchestrate/SKILL.md` (already-landed prerequisite work)

Verified live (3,101 lines total):

- **`hard_mode` derivation** (Stage 1, and again at Stage MT-1 for multi-task): `hard_mode="false";
  [ "$effort_flag" = "hard" ] && hard_mode="true"`. The surrounding comment explicitly says this
  boolean is "reserved for later conditional state-machine branches (churn/three-strikes counters,
  the burnout circuit breaker)" — i.e. this task's WORK is the anticipated consumer of a variable
  that already exists and is already threaded through both single-task and multi-task entry
  points. No new derivation is needed; each new branch below reads the existing `$hard_mode`.
- **Stage 1b (agent routing)** already resolves `RESEARCH_AGENT`/`PLANNER_AGENT`/`IMPLEMENT_AGENT`
  via `command-route-agent.sh "<op>" "$TASK_TYPE" "<default-agent>" "$effort_flag"`, and that
  script's own `routing_agents_hard` block is the sole place `effort_flag="hard"` changes
  resolution. This is the ~50-line Stage 1b residue the design report flagged — it is already a
  unified, non-duplicated mechanism; nothing to port here.
- **Stage 2** already carries a `budget-continuation-override` region (bare, unconditional —
  correct because the mechanism is identical in both modes) but has **no** loop-guard-staleness
  detector and **no** churn-state init. `MAX_CYCLES=5` is a bare literal (line 115), not yet
  conditional.
- **Stage 3.5 Dispatch Prep** (base lines ~344-503) already builds `hard_contracts_block`, gated
  on `hard_mode == "true"`, appending the ordered `context/contracts/*.md` reference list to the
  dispatch prompt for every phase (research/plan/implement). This is task 118's delivered work and
  is NOT part of this task's scope — do not duplicate it.
- **Stage 3** ends its per-cycle preamble at "3c. Dispatch by state" (base lines ~310-320) with no
  gate in between 3b and 3c — this is the exact insertion point for the burnout circuit-breaker
  branch.
- **State: `planned` or `implementing`** handler (base lines 676-701) dispatches the agent once per
  cycle against the *whole plan* (`plan_path` only, no `phase_number`, no `territory` key) — this
  is the handler the H1 branch must wrap or fork.
- **Stage 5 (Handoff Reading)** has zero `hard_mode`/`churn` awareness today — Stage 4b's H6 churn
  check is a genuinely new addition, not a gated variant of an existing base check.

### Migration Target 1 — Loop-Guard / Churn-State Initialization (Stage 2)

Source: `skill-orchestrate-hard/SKILL.md` lines 217-443 (stage header through end of the churn-init
block, before the "Blocker escalation counter" line that is already shared/identical in base).

Three genuinely new pieces, once the already-shared `orchestrate-loop-guard-init.sh` call and the
already-ported `budget-continuation-override` region are excluded:

1. **`MAX_CYCLES` conditional**: hard mode uses `13` (vs. base's `5`) "to accommodate per-phase
   dispatch. Each phase requires its own cycle; a 7-phase plan needs ~7 cycles minimum" (source
   file's own inline note, right after the Stage 2 code fence). Trivial one-line branch at the top
   of Stage 2, before `orchestrate-loop-guard-init.sh` is called (that script takes no MAX_CYCLES
   argument of its own — `MAX_CYCLES` is a bare shell variable set before the call and read
   afterward for the exhaustion/resume messages).

2. **`loop-guard-staleness` 3-signal detector** (source lines 249-317, `--- loop-guard-staleness:begin
   ---` / `:end`): schema/version drift (`max_cycles` mismatch against the live constant),
   plan-lineage drift (`plan_version` field vs. the latest `plans/*.md` basename by `sort -V`), and
   an mtime-age backstop (`ORCHESTRATOR_LOOP_GUARD_STALE_DAYS`, default 7). On any signal firing,
   archives the guard (and co-archives the churn file, if present) to
   `.stale-loop-guard-{ts}.json` / `.stale-churn-state-{ts}.json` and falls through to fresh-init.
   This entire region sits *before* the pre-existing `if [ -f "$loop_guard_file" ]` resume branch
   and *before* `budget-continuation-override`, and never edits either — it only conditionally
   `mv`s files aside so those two regions naturally fall into their existing fresh-init paths. The
   source file's own "Asymmetry decision" note explicitly flags that whether base mode should ever
   gain this 3-signal detector unconditionally is a *separate, undecided* question — for this task,
   the detector is scoped strictly to the `if $hard_mode` branch, not offered to base mode
   generally.

3. **`churn_file` init block** (source lines 425-447): `${TASK_DIR}/.orchestrator-churn-state.json`,
   schema `{session_id, total_churn, target_churn: {}, adversarial_triggers, audit_dispatches}`,
   same init-marker-atomic-creation pattern as the loop guard (`task-lock.sh init-marker`), same
   lost-race resume-read fallback, same non-gating `session_id` mismatch INFO log as the loop guard
   uses.

4. **Two new fields on the loop-guard JSON itself** (visible in the fresh-init `jq -n` literal at
   source lines ~347-364): `"hard_mode": true` and `"burnout_signals_this_session": 0`. The
   resume-read branch correspondingly reads `burnout_signals_this_session=$(jq -r
   '.burnout_signals_this_session // 0' ...)` (source line ~347) alongside the existing
   `cycle_count`/`infra_failures`/`detected_defects`/`dispatch_seq_counter` reads. Base mode's
   fresh-init `jq -n` literal and resume-read branch will need this field added conditionally (or
   always present with `false`/`0` defaults in base mode, which is simpler and avoids a second
   schema fork — recommend always writing `hard_mode` and `burnout_signals_this_session` into the
   guard JSON in both modes, since a stray `// 0`/`// false` fallback already makes old-format
   guards forward-compatible, and it keeps one JSON schema for the file rather than two).

### Migration Target 2 — Burnout Circuit-Breaker Gate (Stage 3c)

Source: `skill-orchestrate-hard/SKILL.md` lines 544-581, in full (~38 lines). This is a **prose
self-check gate**, not primarily a jq-state mechanism — its main body is three MANDATORY
self-check rules read from `context/contracts/orchestrator-discipline.md` (re-read-without-new-
info, second-consecutive-reasoning-turn, reverse-a-decision-without-a-fresh-dispatch), each
telling the orchestrator's own turn-taking behavior to stop and dispatch rather than reason
inline. The only *executable* state-machine piece is the counter increment on any signal firing:

```bash
burnout_signals_this_session=$((burnout_signals_this_session + 1))
jq --argjson count "$burnout_signals_this_session" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '.burnout_signals_this_session = $count | .last_updated = $updated' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

Insertion point in base: between "3b. Update loop guard with current state" and "3c. Dispatch by
state" (base Stage 3, currently ~lines 306-320) — i.e. this becomes base's new "3c" and the
existing dispatch-by-state step is renumbered "3d" (or the new gate is folded into 3b/3c's
existing prose as a `hard_mode`-gated sub-step, avoiding a renumber if the plan phase prefers
minimal structural churn). Runs **every loop iteration** when `hard_mode == "true"`; a no-op
branch (or entirely absent) when `hard_mode == "false"`.

### Migration Target 3 — Churn Detection (H6) + Three-Strikes Audit Dispatch (H5) (Stage 4b)

Source: `skill-orchestrate-hard/SKILL.md` lines 1080-1134, in full (~54 lines). Runs immediately
after each implement-phase dispatch returns (i.e., chained onto the H1 per-phase handler's own
Agent-tool return, before/alongside Stage 5 Handoff Reading — the source file's own heading places
it between the implement dispatch handler and "Stage 5: Handoff Reading"). Logic:

1. Read `$churn_file`'s `total_churn`.
2. Detect a **churn signature**: handoff `status == "partial"` AND `blockers | length > 0` AND
   `phases_completed_after - phases_completed_before == 0` (no phase progress despite a blocked
   handoff).
3. On a signature: increment `target_churn[blocker_target]` and `total_churn` in `$churn_file`
   (atomic tmp-mv write), log `H6: Churn detected on '$blocker_target' (count: $new_target_churn)`.
4. **Three-strikes** (`new_target_churn >= 3`): dispatch `$RESEARCH_AGENT` with a
   `DIVERGENCE AUDIT` prompt (target, verbatim goal, explicit "failed 3 times" framing, asking for
   a divergence table + postmortem + corrected target definition), `delegation_context` carrying
   `orchestrator_mode: false` (research agents never write `.orchestrator-handoff.json` — the
   source file's own comment cites the Stage 3.6 Scoping Decision in
   `general-research-agent.md`/`general-research-hard-agent.md` for why no `handoff_path` is
   passed). Resets `target_churn[blocker_target]` to 0 and increments `audit_dispatches` in
   `$churn_file` after dispatching. Increments `cycle_count`; loop continues (next iteration
   re-dispatches implement with the audit findings already on disk for the agent to read).

This entire block is naturally `if $hard_mode`-gated as a unit — `$churn_file` does not exist (and
`phases_completed_before`/`phases_completed_after` are not meaningfully tracked per-phase) in base
mode's whole-plan-per-cycle dispatch model, so there is no partial/degenerate base-mode variant to
reconcile against; it is purely additive.

### Migration Target 4 — H1 Single-Blocking-Phase-Per-Cycle Limiter

Source: `skill-orchestrate-hard/SKILL.md`, the `#### State: planned or implementing — Per-Phase
Dispatch (H1)` handler, lines 747-966 (~220 lines) plus the adjacent
`build_hard_mode_prompt_context()` helper (lines ~955-967).

This is the largest single migration surface and structurally replaces (rather than decorates)
base's existing whole-plan handler at base lines 676-701 for the hard-mode case. Internal
composition, largest-to-smallest:

- **Heading-scan next-phase selection + skeleton-exhaustion routing** ("772 Item 5A", source lines
  ~765-949, the bulk of the handler): sources `scripts/lib/phase-heading-patterns.sh`, checks
  `has_nonconforming_phase_headings` first (fail-closed to `EXIT (partial, ...)` if the plan's
  heading grammar can't be scanned), then greps the first OPEN-status phase heading and extracts
  its number via `extract_phase_number`. This mirrors `general-implementation-hard-agent.md`
  Stage 3b's *already-landed* fix per the source file's own comment — i.e. it is a proven,
  independently-tested pattern being ported into a second consumer, not novel design.
- **Marker/handoff crosscheck** ("Defect 6", source lines ~820-841): compares the plan's own
  `[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]` heading count against the handoff's
  `phases_completed` field; on mismatch, downgrades the disputed heading to `[PARTIAL]` and exits
  partial rather than dispatching over unconfirmed work.
- **`dispatch_context` construction** (source lines ~866-885): adds `phase_number` and a
  `territory` object (`owned_files`/`read_only_files`/`forbidden_files`/`concurrency_note`) not
  present in base's dispatch context — base's multi-task dispatch is genuinely concurrent by
  construction and deliberately has no `territory` key (per the source file's own "Territory
  asymmetry acknowledgment" note); hard mode's per-phase dispatch is single-agent-at-a-time so the
  key documents intra-task predecessor-wake hazards instead.
- **`build_hard_mode_prompt_context()`** (source lines ~955-967): constructs the phase-scoped
  "HARD MODE DISPATCH — CONTRACT SLOTS" prompt block (mission = "implement phase $next_phase only",
  plus references to anti-analysis/wrap-up/settled-design/recovery contracts). **Caution**: this
  looks adjacent to task 118's `hard_contracts_block` (Stage 3.5's contract-TEXT injection) but is
  a *different* mechanism — `build_hard_mode_prompt_context()` is phase-mission framing specific to
  the H1 per-phase dispatch prompt, not the shared ordered `context/contracts/*.md` reference list.
  Confirm during planning whether task 118's `hard_contracts_block` already subsumes this content
  (likely — the four contract names it lists — anti-analysis, wrap-up, settled-design preamble,
  recovery — match Stage 3.5's existing contract set) to avoid emitting it twice in the hard-mode
  implement prompt.
- **Skeleton-exhaustion else-if branch** (source lines ~919-946): when no OPEN phase heading
  remains and the last handoff declared `skeleton: true`, routes completion through the `pr_ready`
  postflight target argument (which resolves to `completed` for non-`pr` task types per
  `update-task-status.sh`'s postflight mapping — already documented in `status-markers.md`), reading
  follow-up tasks from `wrap_up.md`'s shipped `sorry_inventory[].follow_up_task` field. This
  sub-branch has no base-mode equivalent to fork against; base mode has no skeleton concept.
- **Trailing else (all phases complete, non-skeleton)**: falls through with no new dispatch,
  deferring to Stage 5's `phases_completed >= phases_total` completion gate — this is the one
  sub-branch whose *behavior* (not code shape) already matches what base mode's Stage 5 gate does
  for a whole-plan dispatch that reports full completion, so the fork can converge back to shared
  Stage 5 handling here.

**Recommended fork shape**: given the structural mismatch (whole-plan single dispatch vs.
phase-scanning multi-branch state machine), a single `if [ "$hard_mode" = "true" ]; then
<H1 handler> else <existing whole-plan handler> fi` around the entire `#### State: planned or
implementing` body is cleaner than threading `if $hard_mode` checks through each of H1's internal
branches — the two handler bodies solve the same STATE but via genuinely different mechanisms, matching
how the design report itself describes this residue as "conditional STATE-MACHINE logic," not
prompt decoration of one shared body.

### `Key Differences` Reference Table (source file's own summary, verified accurate)

The hard-mode file's own closing comparison table (source lines ~1782-1792) is a useful acceptance
checklist for what "fully migrated" looks like once this task and its sibling contract-injection
work are both live inside the single engine:

| Feature | Base (today) | Hard (`skill-orchestrate-hard`, to be ported behind `if $hard_mode`) |
|---------|------------------|----------------------|
| MAX_CYCLES | 5 | 13 |
| Implement dispatch | Whole plan per cycle | One phase per cycle (H1) |
| Adversarial gate | None | Research verified before plan (H4) — **out of scope**: not in this task's WORK list; verify with `/plan` whether H4 belongs here or was already covered elsewhere |
| Churn detection | None | Per-target counters (H6) — this task |
| Three-strikes | None | Audit dispatch at 3 (H5) — this task |
| Parallel dispatch | None | Disabled — single blocking phase per cycle — already true of base's multi-task-per-task dispatch model per the territory-asymmetry note; no separate work needed |
| Prompt construction | Simple | Contract-slot injection — task 118, done |

**Flag for `/plan`**: the task's own WORK list (loop-guard/churn-init, burnout breaker, H6/H5
churn+three-strikes, H1 phase limiter) does not mention H4's adversarial-verification-before-plan
gate, even though the table above lists it as hard-only. Confirm during planning whether H4 is
genuinely out of this task's scope (a 5th residue category the design report may have intended for
a different task, or already folded into task 118's contract-injection work as a text-only gate)
before treating the WORK list's four items as the complete migration.

## Decisions

- Scope this task strictly to the four WORK-list items; treat H4 adversarial verification as an
  open question for the plan phase rather than silently including or excluding it.
- Recommend keeping loop-guard JSON schema unified (add `hard_mode`/`burnout_signals_this_session`
  fields in both modes, `false`/`0` defaulted) rather than forking the guard schema per mode, to
  avoid a second schema the retarget task (120) and any future reader would need to disambiguate.
- Recommend the `loop-guard-staleness` 3-signal detector stay strictly `if $hard_mode`-gated per
  the source file's own explicit "Asymmetry decision" — do not extend it to base mode as a side
  effect of this migration.
- Recommend forking the entire `#### State: planned or implementing` handler body on `hard_mode`
  rather than threading conditionals through H1's internal sub-branches, since the two
  implementations solve the same state via structurally different mechanisms.
- Flag, don't resolve: whether `build_hard_mode_prompt_context()`'s phase-mission text duplicates
  content task 118's `hard_contracts_block` already injects — the planner should check the current
  `hard_contracts_block` construction in Stage 3.5 against this list before deciding whether to
  port the phase-mission framing verbatim or trim overlapping contract references.

## Risks & Mitigations

- **Edit collision with sibling tasks 117/118 on the same file**: mitigated — both are already
  `[COMPLETED]` in `specs/TODO.md`/state, so no concurrent-edit window remains open against this
  file for those two tasks specifically. Task 120 (test/lint retarget) and task 121 (deletion) are
  both explicitly gated to run *after* this task, so no forward collision either. Verify no other
  concurrently-running dispatch is mid-edit on `skill-orchestrate/SKILL.md` immediately before
  `/plan`/`/implement` for this task begin (the task directory's `.lock/holder.json` /
  `.orchestrator-loop-guard` are this task's own orchestrator runtime files, not evidence of a
  second editor).
- **File size**: `skill-orchestrate/SKILL.md` is already 3,101 lines before this task's ~350-400
  line net addition (the four items combined, minus what's genuinely shared/no-op in base mode).
  No action needed — this is the file the design report intends as the sole surviving engine; size
  growth is the accepted tradeoff for consumer-count reduction, per A4's own framing.
- **Renumbering Stage 3's lettered sub-steps** (3a/3b/3c) when inserting the burnout gate risks
  drifting other in-file cross-references to "3c. Dispatch by state" (grep found this phrase used
  as a forward-reference elsewhere, e.g. "See State Handlers in Stage 4"). Mitigation: prefer
  folding the burnout gate into existing 3b/3c prose as an `if $hard_mode` sub-step over
  renumbering, or grep all `3c\b` references in the file before renumbering and update them in the
  same edit.

## Context Extension Recommendations

None — this is a meta task whose only relevant context (`context/patterns/dispatch-report-not-
termination.md`, `context/standards/orchestrator-runtime-files.md`, `context/contracts/*.md`) is
already documented and already referenced correctly by both source files.

## Appendix

- Files read in full or by targeted range: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  (stage-header survey + Stage 1/1b/2/3/3.5/676-760 targeted reads), `agent-system/extensions/core/skills/skill-orchestrate-hard/SKILL.md`
  (stage-header survey + Stage 2/3c/4b/747-970/1770-1800 targeted reads), `specs/116_core_agent_system_consolidation/reports/03_target-state-design.md`
  (A4 section, lines 180-320), `specs/TODO.md` (task entries 117-121, 127).
- Search queries used: grep for `hard_mode`, `churn`, `burnout`, `three-strike`, `H1`,
  `phases_completed`, `MAX_CYCLES`, `Stage N:` headers in both SKILL.md files.
